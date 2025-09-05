# GeoServer - Keycloak Compose Setup

This is a simple dockerized Geoserver & Keycloak setup demonstrating the usage of the
OpenID Connect plugin.

NOTE: DO NOT USE THE PROVIDED CONFIGURATION AS IS IN PRODUCTION!

## Usage

1. Execute `./setEnvironment.sh create` to create the required environment.

2. Start the containers via:

```bash
docker-compose up
```

3. Import the Keycloak configuration via:

```bash
docker cp ./keycloak/init_data/keycloak_export.json geoserver-keycloak-openid-keycloak-1:/tmp/keycloak_export.json
docker exec -it geoserver-keycloak-openid-keycloak-1 /opt/keycloak/bin/kc.sh import --file /tmp/keycloak_export.json
```

4. Login to GeoServer (`admin:geoserver`) and navigate to `Authentication`, select `keycloak-openid-connect` from
   the list of `Authentication Filters` and replace the IP in all fields by your local one.

## Services

- [https://localhost/geoserver](https://localhost/geoserver)
  - Credentials: `admin:geoserver`
- [https://<YOUR_IP>/auth](https://<YOUR_IP>/auth)
  - Credentials: `admin:admin`
  - Example user in `GEOSERVER` realm: `geoserver:geoserver`

## Resources

- https://docs.geoserver.org/stable/en/user/community/oauth2/oidc.html

## Testing

### Get an access token

- `scope=openid` is quite important!

```bash
curl \
  -v \
  -k \
  -X POST \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=password' \
  -d 'scope=openid' \
  -d 'client_id=login' \
  -d 'username=geoserver' \
  -d 'password=geoserver' \
  'https://localhost/auth/realms/GEOSERVER/protocol/openid-connect/token' | jq '.access_token'
```

### Get the userinfo

```bash
curl \
  -v \
  -X GET \
  -k \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  "https://localhost/auth/realms/GEOSERVER/protocol/openid-connect/userinfo"
```

### Test WMS GetMap

#### Authenticated

```bash
curl \
  -v \
  -X GET \
  -k \
  -H 'Authorization: Bearer <ACCESS_TOKEN>' \
  "https://localhost/geoserver/tiger/wms?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap&FORMAT=image%2Fpng&TRANSPARENT=true&STYLES&LAYERS=tiger%3Apoly_landmarks&SRS=EPSG%3A4326&WIDTH=528&HEIGHT=768&BBOX=-74.0097427368164%2C40.71327209472656%2C-73.91910552978516%2C40.84510803222656"
```

#### Anonymous

```bash
curl \
  -v \
  -X GET \
  -k \
  "https://localhost/geoserver/tiger/wms?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap&FORMAT=image%2Fpng&TRANSPARENT=true&STYLES&LAYERS=tiger%3Apoly_landmarks&SRS=EPSG%3A4326&WIDTH=528&HEIGHT=768&BBOX=-74.0097427368164%2C40.71327209472656%2C-73.91910552978516%2C40.84510803222656"
```
