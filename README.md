Get a server with Ubuntu, this final setup uses about 1GB of RAM

Install Docker: https://docs.docker.com/engine/install/ubuntu/

Install Nomad: https://developer.hashicorp.com/nomad/docs/install
Install CNI things for bridge networking to work:
https://developer.hashicorp.com/nomad/docs/networking/cni#create-a-cni-bridge-mode-configuration

Install Consul: https://developer.hashicorp.com/consul/install#linux

enable nomad acl

```shell
root@sst-nomad-thing:/etc/nomad.d# cat nomad.hcl 
data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"

server {
  enabled          = true
  bootstrap_expect = 1
}

plugin "docker" {
  config {
    volumes {
      enabled = true
    }
  }
}

plugin "containerd-driver" {
  config {
    containerd_runtime = "io.containerd.runc.v2"
}

client {
  enabled = true
  servers = ["127.0.0.1"]
}

acl {
  enabled = true
}
```

systemctl enable --now nomad

```shell
root@sst-nomad-thing:/etc/nomad.d# nomad acl bootstrap
Accessor ID  = faacbd2a-1085-8552-5e14-1bc604d95ace
Secret ID    = 3f30403d-f5a3-00ff-b00f-bd256721b867
Name         = Bootstrap Token
Type         = management
Global       = true
Create Time  = 2024-10-16 13:08:38.082016962 +0000 UTC
Expiry Time  = <none>
Create Index = 14
Modify Index = 14
Policies     = n/a
Roles        = n/a
```

save secret id

do export NOMAD_TOKEN="secret_id"

do `nomad acl token create -name="frontend" -type="management"`
do `nomad acl token create -name="sst" -type="management"`

save secret ids

consul config

```shell
root@sst-nomad-thing:/etc/consul.d# cat consul.hcl 
node_name = "local-consul"
server = true
bootstrap_expect = 1

connect {
  enabled = true
}

bind_addr = "127.0.0.1"
advertise_addr = "127.0.0.1"

```

systemctl enable --now consul # might hang up, just ctrc + c

we do `ss -tuln` and see that consul is bound to localhost and not accessible from outside

from now on 10.11.12.13 is your server public ip

visit 10.11.12.13:4646/ui, you should see nomad ui, auth with frontend token

pro

nomad is though

create A records for nomad and your service pointing to the server
A example.com 10.11.12.13
A nomad.example.com 10.11.12.13

get CF_ZONE_API_TOKEN for traefik dns challenge to get tls certs, specify the zone you want example.com
https://dash.cloudflare.com/profile/api-tokens
https://doc.traefik.io/traefik/https/acme/
https://doc.traefik.io/traefik/user-guides/docker-compose/acme-dns/
https://doc.traefik.io/traefik/https/acme/#providers

do `consul kv put traefik/cf_dns_api_token <token>`

create folders `/opt/letsencrypt` and `/opt/traefik`

in `/opt/traefik/dynamic-config.yml` put this:
```yaml
http:
  routers:
    nomad:
      rule: "Host(`nomad.example.com`)"
      entryPoints:
        - websecure
      service: nomad
      tls:
        certResolver: myresolver

  services:
    nomad:
      loadBalancer:
        servers:
          - url: "http://PUBLIC_IP:4646"

```

first provision will be done over http without tls, then traefik will get the cert and switch to https


init sst somehow, do `sst add nomad`, with pnpm you'll do `pnpm dlx sst add nomad`
change home to 'local' in config

create .env file

put this inside

```shell
NOMAD_URL=http://10.11.12.13:4646/
NOMAD_TOKEN=nomad-sst-secret-id # we created earlier

```

comment everything but nomad and traefik


do `env $(cat .env | xargs) sst deploy`

observe the traefik job, once it's healthy check traefik logs, check that everything is ok, then check /opt/letsencrypt/acme.json, it should be populated with certs

if you can visit https://nomad.example.com and see the ui, then everything is working fine

now we need to rotate sst and frontend tokens

on the server do

```shell
root@sst-nomad-thing:/opt/letsencrypt# nomad acl token list
Name             Type        Global  Accessor ID                           Expired
Bootstrap Token  management  true    f4ab3e26-ce1d-11e6-3d9a-238db337c10a  false
frontend         management  false   0d60c989-a5b4-874a-2940-43e7549a060c  false
sst              management  false   0b0f1d6b-85e4-d654-4635-7775dcbe43db  false
```

if you get access denied do `export NOMAD_TOKEN=secret_id`

delete tokens:
```shell
root@sst-nomad-thing:/opt/letsencrypt# nomad acl policy delete 0d60c989-a5b4-874a-2940-43e7549a060c 
Successfully deleted 0d60c989-a5b4-874a-2940-43e7549a060c policy!
root@sst-nomad-thing:/opt/letsencrypt# nomad acl policy delete 0d60c989-a5b4-874a-2940-43e7549a060c
Successfully deleted 0d60c989-a5b4-874a-2940-43e7549a060c policy!
```

recreate tokens for frontend and sst like we did before, save them

update NOMAD_TOKEN in .env file
change NOMAD_URL to https://nomad.example.com

okay, now you can transport secrets to the server over encrypted connection since we have https figured out

do `env $(cat .env | xargs) sst deploy` again, it will error out, do `env $(cat .env | xargs) sst deploy` again, everything should be fine

okay initial setup is done, nomad is reasonably secure, traefik is working

uncomment `echo` and `postgres` in sst config, do `env $(cat .env | xargs) sst deploy`

visit the ui, you should see jobs, wait for them to be healthy

visit https://example.com, you should see something like:

```shell
DATABASE_URL: postgres://oofer:super-secret@10.11.12.13:24847/boofer

CURRENT_PORT: 28721
```

notice that database connection is performed over public IP, but the port is not open on the host, so it's not accessible from outside

do `ss -tuln`, check that the only things exposed are traefik and nomad (ports 80, 443, 4646, 4647 and 4648)

refresh a page a few times, notice that CURRENT_PORT changes, this is because we have a load balancer in front of the service