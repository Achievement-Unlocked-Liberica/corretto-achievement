

# Overview


The following steps will cover from the setup of the services to the deployment of the insfrastructure and services



## Create Package Read-Only GitHub Token 

- Click on your profile picture
- In the right menu, select 'Settings'
- In the left menu, select 'Developer Tools'
- In the left menu, select 'Tokens (Classic)'
- Create a new Personal Access Token
- Set a name for the token, for example: 'PAT-Read-Packages'
- In the scopes, select 'read:packages'
- We don't need any other permissions, the objective of the token is to allow for the infrastructure scripts to access the GHCP image/package repositories
- Set the expiration to an appropriate value, do not set it to 'not expire'
- Copy the value to a safe place


## Create Kubernetes Secrets

### Create Secrets

- Run the 'cluster-configuration\setup.sh' script
- Provide the name of the cluster and the namespace as inline parameters

    For example: 
    ```
    ./setup.sh {cluster-name} {namespace}
    ```
- The script will ask for the github user and token value (from previous step)
- After execution, verify that the secret was created.

## Create Kubernetes Base Resources

### Install NGINX, CERT-MANAGER and JETSTACK

- Run the setup script

```
cluster-resources\ngnix\setup.sh
```

- The script might take a few minutes to complete, since the setup waits for the External IP to be provided
- Some of the resources might already exist
- If the NGINX install gets stuck waiting for the pods to be ready, cancel the script and re-run it
