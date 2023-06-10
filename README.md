## Kafka Connect facilitator

### Configure

```sh
git clone REPO_URL $HOME/kafka-connect-cli
echo "export PATH=\$PATH:$HOME/kafka-connect-cli" >> ~/.bashrc
source $HOME/.bashrc
```
### Examples

```sh
# Create port forward
kfconnect create_port_forward dev service-name

# List connectors 
kfconnect list | jq '.'

# Get connector configuration 
kfconnect get_connector <connector-name> | jq '.'

# Create a connector, provide a path to the connector's JSON configuration
kfconnect create <config-file-path>

# Delete a connector
kfconnect delete <connector-name>

# Get trace error of the first task of a connector
kfconnect get_error <connector-name>

# Check connector status
kfconnect status <connector-name> | jq '.'

# Validate connector configuration, provide a path to the connector's JSON configuration
kfconnect validate_connect_config <config-file-path> | jq '.'
```