# Migration Notes
Notes on migrating from one CKAN to another

## Getting Started
Setup CKAN API:
```bash
pip3 install ckanapi
```

## Migration Commands
### Setup
```bash
SOURCE_CKAN_URL=<source CKAN URL goes here, e.g. https://data.opendata.durban>
SOURCE_CKAN_API_KEY=<source CKAN API key, e.g. a545db6b-abb0-49ee-9e84-bc9869767c10>
DESTINATION_CKAN_URL=<destination CKAN URL goes here, http://ec2-34-211-46-219.us-west-2.compute.amazonaws.com/>
DESTINATION_CKAN_API_KEY=<destination CKAN API key, e.g. a545db6b-abb0-49ee-9e84-bc9869767c12>
TMP_DIR=<temp scratch dir to use during copying>
```

### Users
Pulling out the users:
```bash
ckanapi dump users --all -q -r $SOURCE_CKAN_URL -a $SOURCE_CKAN_API_KEY -O "$TMP_DIR"/user_dump.json
```

Loading into new CKAN:
```bash
ckanapi load users --all -q -r $DESTINATION_CKAN_URL -a $$DESTINATION_CKAN_API_KEY -I "$TMP_DIR"/user_dump.json
```

*NB* A change from CKAN 2.8 to 2.9 is that Users no longer have static API keys. A user can rather generate (and revoke) 
API tokens. More care is taken in the WUI to make sure that these aren't shown in plain text.

### Organisations
Pulling out the org data:
```bash
ckanapi dump organizations --all -q -r $SOURCE_CKAN_URL -a $SOURCE_CKAN_API_KEY -O "$TMP_DIR"/org_dump.json
```
Loading into new CKAN:
```bash
ckanapi load organizations -r $DESTINATION_CKAN_URL -A $DESTINATION_CKAN_API_KEY -I "$TMP_DIR"/org_dump.json
```

### Groups
_lector cave_ *untested* 

Pulling out the group data:
```bash
ckanapi dump groups --all -q -r $SOURCE_CKAN_URL -a $SOURCE_CKAN_API_KEY -O "$TMP_DIR"/group_dump.json
```

Loading into the new CKAN:
```bash
ckanapi load groups -r $DESTINATION_CKAN_URL -a $DESTINATION_CKAN_API_KEY -I "$TMP_DIR"/group_dump.json
```

### Datasets
*NB* This just transfers the dataset metadata across. The actual data files will have to be transferred via another means.

```bash
ckanapi search datasets "include_private=True" -r $SOURCE_CKAN_URL -a $SOURCE_CKAN_API_KEY -O "$TMP_DIR"/datasets_dump.json
```

```bash
ckanapi load datasets -r $DESTINATION_CKAN_URL -a $DESTINATION_CKAN_API_KEY -I "$TMP_DIR"/datasets_dump.json
```

### Cleanup
```bash
rm "$TMP_DIR"/*_dump.json
```