# Vault Kubernetes Workshop on Google Cloud Platform

## Prerequisites &amp; Caveats

- This workshop is designed to be run on [Google Cloud Shell][cs]. It may work
  in other environments without modification, but the materials are only tested
  and guaranteed against Cloud Shell.

- You must have a Google Cloud Platform account and be authenticated as a
  project owner. Again, if you are using Cloud Shell, this happens
  automatically. If you are running locally, you will need to download and
  install the [Google Cloud SDK][sdk], and then authenticate to Google Cloud
  appropriately.

- There are places where this workshop sacrifices "best practices" for "things
  feasible to complete in the duration of a workshop". In particular, this
  workshop generates self-signed SSL certificates and does not encrypt the
  resulting keys. For more details on a production-hardened setup, please see
  the [Vault production hardening docs][vault-prod-hardening].

- You must clone this repo:

    ```text
    git clone https://github.com/sethvargo/vault-kubernetes-workshop
    cd vault-kubernetes-workshop
    ```

## 00 Install Vault

The first step is to install Vault. To install the Vault binary in the current
working directory, run the install script.

```text
./scripts/00-install-vault.sh
```

This will install Vault using the `sethvargo/hashicorp-installer` Docker
container which verifies GPG signatures and checksums from the download.

This represents a "best practices" installation for installing secure software
like Vault. By verifying the signature of the SHASUMs and then verifying the
SHASUMs themselves, we guarantee both the integrity of the download and ensure
the binary has not been tampered with beyond it's original publishing. For added
security, you can download and compile Vault yourself from source, but that is
out of scope for this workshop.

Cloud Shell does not persist things in `/usr/local/bin` or `/usr/bin` between
sessions. As such, Vault will be installed in `~/bin`. We recommend installing
other binaries or software you need between sessions in this folder.

## 01 Enable Services

By default, a new Google Cloud project does not have many services enabled.
Enable the required services (this only needs to be done once per project):

```text
./scripts/01-enable-services.sh
```

This will make the necessary calls to enable the enable the right APIs on your
project. This process can take some time, but it is idempotent (you can run it
multiple times to achieve the same result).

## 02 Setup Storage

Vault requires a storage backend to persist its data. This workshop leverages
[Google Cloud Storage][gcs]. Vault does not automatically create the storage
bucket, so we need to create:

```text
./scripts/02-setup-storage.sh
```

Cloud Storage bucket names must be globally unique across all of Google Cloud.
The bucket will be named "${PROJECT}-vault-storage".

For security purposes, it is not recommended that other applications or services
have access to this bucket. Even though the data is encrypted at rest, it is
best to limit the scope of access as much as possible.

## 03 Setup KMS

Vault will leverage [Google Cloud KMS][kms] to encrypt its unseal keys for
auto-unsealing and auto-scaling purposes. We must create the KMS key in advance:

```text
./scripts/03-setup-kms.sh
```

## 04 Create IAM Service Account

It is a best practice to create a limited, dedicated service account that has
only the required permissions. Create a dedicated service account in the project
and grant it the most minimal set of permissions, in particular:

- The ability to read/write to the Cloud Storage bucket created above
- The ability to encrypt/decrypt data with the KMS key created above
- The ability to generate new service accounts (not required to use Vault, but
  helpful if you plan to use the Vault GCP secrets engine)

```text
./scripts/04-create-iam-service-account.sh
```

## 05 Create Kubernetes Cluster

Next we need to create the [Google Kubernetes Engine][gke] (GKE) cluster which
will run Vault. It is recommended that you run Vault in a dedicated namespace or
(even better) a dedicated cluster and a dedicated project. Vault will then act
as a service with an IP/DNS entry that other projects and services query.

```text
./scripts/05-create-k8s-cluster.sh
```

This will create the cluster and attach the service account created in the
previous step to the cluster. It also ensures the cluster has the correct oauth
scopes.

## 06 Create Public IP

This step creates and reserves a regional public IP address. In a future step,
we will attach this reserved IP address to a Kubernetes load balancer. For now,
we will just reserve the dedicated IP address.

```text
./scripts/06-create-public-ip.sh
```

We use a regional IP address instead of a global IP address because global IPs
perform load balancing at L7 whereas regional IP addresses perform load
balancing at L4. Ideally we do not want the load balancer to perform TLS
termination, and let Vault manage TLS, etc. While recent versions of Vault do
support advanced routing like `X-Forwarded-For` headers, it is still a better
practice to let Vault fully manage the TLS and thus use an L4 load balancer.

This step is not required if you are comfortable assigning your Vault Kubernetes
service an ephemeral IP or will manage it via an external DNS service.

## 07 Create Certificates

This is arguably the most complex and nuanced piece of the workshop - generating
Vault's certificate authority and server certificates for TLS. Vault can run
without TLS, but this is _highly_ discouraged. This step could be replaced with
a trusted CA like Let's Encrypt, but that is out of scope for this workshop.

```text
./scripts/07-create-certs.sh
```

This will create the Certificate Authority (`ca.key`, `ca.crt`) and Vault
certificate (`vault.key`, `vault.crt`). In a future step, we will put these
values in a Kubernetes secret so our pods can access them.

## 08 Create Config

Next we create the config map and secrets to store our data for our pods. The
insecure data such as the storage bucket name and IP address are placed in a
configmap. The secure data like the TLS certificates are put in a Kubernetes
secret.

```text
./scripts/08-setup-config.sh
```

## 09 Deploy Vault

The next step is to actually deploy Vault as a StatefulSet on Kubernetes. The
reason we use a StatefulSet is two-fold:

1. It guarantees exactly one service starts at a time. This is required by the
[vault-init][vault-init] sidecar service.

1. It gives us consistent naming for referencing the Vault servers (which is
nice for a workshop).

```text
./scripts/09-deploy-vault.sh
```

Vault will automatically be initialized and unsealed via the vault-init service.

## 10 Deploy Load Balancer

Even though Vault is deployed, it is not publicly accessible. We need to create
a Kubernetes Service Load Balancer to forward from the IP address reserved in
the previous steps to the pods we just created.

```text
./scripts/10-deploy-lb.sh
```

The load balancer listens on port 443 and forwards to port 8200 on the
containers.

For production-hardened scenarios, you may want to include firewall rules to
limit access to Vault at the network layer.

## 11 Setup Comms

Lastly, we need to configure our local Vault CLI to communicate with these
newly-created Vault servers through the Load Balancer. Since we used custom TLS
certificates, we'll need to trust the appropriate CA, etc. This will:

- Set `VAULT_ADDR` to the Load Balancer address

- Set `VAULT_CAPATH` to the path of the CA cert created in previous steps for
  properly verifying the TLS connection

- Set `VAULT_TOKEN` to the decrypted root token by decrypting it from KMS

```text
./scripts/11-setup-comms.sh
```

At this point, the local Vault CLI is configured to communicate with our Vault
cluster. Verify by running `vault status`:

```text
vault status
```

## 12 Setup Static KV

Next we will explore techniques for retrieving static (i.e. non-expiring)
credentials from Vault. The kv secrets engine is commonly used with legacy
applications which cannot handle graceful restarts or when secrets cannot be
dynamically generated by Vault.

```text
./scripts/12-setup-static-kv.sh
```

This will:

1. Enable the KV secrets engine
1. Create a policy to read data from a subpath
1. Store some static username/password data in the secrets engine

Try reading back the secret by running:

```text
vault kv get secret/myapp/config
```

You can also read the data via a request tool like curl.

```text
curl -k -H "x-vault-token:${VAULT_TOKEN}" "${VAULT_ADDR}/v1/secret/myapp/config"
```

## 13 Another Cluster

Next we are going to create another Kubernetes cluster. There is no requirement
that our Vault servers run under Kubernetes (they could be running on dedicated
VMs or as a managed service). It is a best practice to treat the Vault server
cluster as a "service" through which other applications and services request
credentials. As such, moving forward, the Vault cluster will be treated simply
as an IP address. We will not leverage K8S for "discovering" the Vault cluster,
etc.

**To put it another way, completely forget that Vault is running in Kubernetes.
If it helps, think that Vault is running in a PaaS like Heroku instead.**

Next create the Kubernetes cluster where our services will actually run. This is
completely separate from the Vault K8S cluster. In fact, on GCP, is it
recommended that you run these in completely separate projects. For the purpose
of this workshop, we will run them in the same project.

```text
./scripts/13-create-another-cluster.sh
```

This will provision a new Kubernetes cluster named "my-apps". We will deploy
all future apps and services in this cluster.

Unlike the previous cluster, this cluster does not attach a service account.

## 14 Service Account

In our cluster, services will authenticate to Vault using the [Kubernetes auth
method][vault-k8s-auth-method]. In this model, services present their JWT token
to Vault as part of an authentication request. Vault takes that signed JWT token
and, using the token reviewer API, verifies the token is authenticated. If the
authentication is successful, Vault generates a token and maps a series of
configured policies onto the token which is returned to the caller.

```text
./scripts/14-create-service-account.sh
```

This will create a dedicated service account named "vault-auth" and grant that
service account the ability to communicate with the token reviewer API.

## 15 Configure Vault to talk to Kubernetes

Next we need to configure the Vault cluster to talk to our new Kubernetes
cluster ("my-apps"). We will need to give Vault the IP address of the
cluster, the CA information, and the service account to use for accessing the
token reviewer API.

```text
./scripts/15-setup-vault-comms-k8s.sh
```

This process will:

1. Look up the service account JWT token (this is how Vault will talk to the
Kubernetes API)

1. Extract the Kubernetes host from the local kube configuration (this where
Vault will make API requests)

1. Extract the Kubernetes CA from the local kube configuration (this is how
Vault will authenticate requests)

1. Enable the Kubernetes auth method in Vault

1. Give Vault the service account JWT, host, and CA so that Vault can
communicate with Kubernetes

There are other techniques for retrieving some of these values, but leveraging
`kubectl` makes it easy to script.

## 16 Create KV Role

Typically this process is done by a security team or operations team. We need to
configure Vault to map an application or service in Kubernetes to a series of
policies in Vault. That way, when an application successfully authenticates to
Vault via its JWT token, Vault knows which policies to assign to the response.

```text
./scripts/16-create-kv-role.sh
```

This will create a role named "myapp-role" that permits pods in the "default"
namespace with the "default" service account to receive a Vault token that has
the "myapp-kv-rw" policy attached.

## 17 Sidecar Static App

This is one of the most common techniques for injecting Vault secrets into an
application.

1. An init container pulls the service account JWT token and performs the auth
mechanism for that service account. If successful, it stores the resulting
_Vault_ token in somewhere on a shared volume mount.

1. A tool like [Consul Template][consul-template] runs as the first container.
This tool uses the Vault token acquired by the init container and makes the
appropriate API calls to Vault based off of a template file. The template file
can reference one or more Vault credentials. Consul Template writes the rendered
file with the secrets from Vault to a shared volume mount which the app reads.

1. The app reads credentials. In this example, our application is a dummy
application that just reads the contents of `/etc/secrets/config` repeatedly.

```text
./scripts/17-run-kv-sidecar.sh
```

Verify the app is authenticating and retrieving secrets from Vault:

```text
./scripts/kubectl-logs.sh kv-sidecar
```

## 18 Setup Dynamic Credentials

Next we configure Vault to generate dynamic credentials. Vault can generate many
types of dynamic credentials like database credentials, certificates, etc. For
this example, we will leverage the GCP secrets engine to dynamically generate
Google Cloud Platform CloudSQL MySQL users.

```text
./scripts/18-setup-dynamic-creds.sh
```

This will:

1. Create a CloudSQL database

1. Enable the `database` secrets engine

1. Configure the `database` secrets engine

1. Create a "role" which configures the permissions the SQL user has

1. Create a new policy which allows generating these dynamic credentials

1. Update the Vault Kubernetes auth mapping to include this new policy when
authenticating

This process can take up to 10 minutes to complete.

## 19 Sidecar Dynamic App

In this example, we follow the same pattern as the static KV secrets, but our
sidecar application will pull dynamic credentials from Vault. In this case, we
will be creating a database password.

```text
./scripts/19-run-db-sidecar.sh
```

This also configures a command to run which will signal the application when the
underlying service account changes. This is important as we need to notify the
application (which is not aware of Vault's existence) that it should reload its
configuration.

Verify the app is authenticating and retrieving secrets from Vault:

```text
./scripts/kubectl-logs.sh db-sidecar
```

[cs]: https://cloud.google.com/shell
[gcs]: https://cloud.google.com/storage
[gke]: https://cloud.google.com/gke
[kms]: https://cloud.google.com/kms
[sdk]: https://cloud.google.com/sdk
[consul-template]: https://github.com/hashicorp/consul-template
[vault-init]: https://github.com/sethvargo/vault-init
[vault-k8s-auth-method]: https://www.vaultproject.io/docs/auth/kubernetes.html
[vault-prod-hardening]: https://www.vaultproject.io/guides/operations/production.html
