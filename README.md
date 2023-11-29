# mongo-upgrade
Script to upgrade Mongodb v3.4 to v6.0

## Pre requisites
 1. user should be part of sudo group
 2. mongo user should have admin access to list databases
 3. this script was tested using `ssm-user` user on the dev and AMI's of ushur DEMO,MOCK DEMO and COMMUNITY VM's
## Execution steps

 1. `$ cd /tmp/`
 2. Clone this repo on the target instance  `$git clone https://github.com/mathew-er/mongo-upgrade.git` using the personal access token shared
 3. navigate to `cd /tmp/mongo-upgrade/`
 4. ensure the mongo server does not have any replicaSets, if present we need to unset a field
 5. steps to check replicaSet present and unset it 
    - `$ mongo -u <user-name> -p <password> --port <port> --authenticationDatabase=<db>`
    - `$ use local`
    - `$ db.replset.minvalid.find({}).pretty ();`
    - get the objectId from the response ,sample below
         ```
            {
                "_id" : ObjectId("57b18fb43040dc07cefc3235"),
                "ts" : Timestamp(1505648110, 6),
                "t" : NumberLong(-1),
                "oplogDeleteFromPoint" : Timestamp(0, 0)
            }```
    - `$ db.replset.minvalid.update(  { "_id" : ObjectId("<objectId>")},    { $unset: { oplogDeleteFromPoint: ""} } );`

 6. once replica Set issue is resolved ,we can execute our script
   - `$ sh mongo-upgrade-v1.sh`

 7. if replica Set issue is not resolved , the script will fail at mongodb v4.0 ->v4.2 upgrade throwing the error as mentioned in this [ticket](https://www.mongodb.com/community/forums/t/failed-to-start-mongo-service-after-update-from-4-0-to-4-2/7640/3)
   - under this scenario , do the below steps
   - erase current binary and re-install v4.0 binaries and start the server
      - `$sudo yum erase $(rpm -qa | grep mongodb-org) -y && \
echo "removed mongodb" && \
sudo sed -i 's/4\.2/4\.0/g' /etc/yum.repos.d/mongodb-org.repo && \
echo "updated mongodb yum repo" && \
sudo yum install -y mongodb-org && \
echo "mongodb installation completed" && \
sudo cp /etc/mongod.conf.bkp /etc/mongod.conf && \
echo "updated mongodb conf file" && \
sudo chown mongod:mongod /etc/mongod.conf && \
echo "updated mongodb ownership" && \
echo "restarting mongodb v4.0" && \
sudo systemctl start mongod`
  - in the `mongo-upgrade-v1.sh` script , comment the versions already upgraded , ie 
     - v3.4 -> 3.6 
     - v3.6-> v4.0
- perform the replica set `unset` commands in step (5)
- rerun the script
## Actions
The script will do the following
 1. get credentials from vault
 2. get count of all objects in each collection
 3. get stats of all dbs
 4. stop the database ,replace the binaries and install the next versions recursively and start upgrading the data also
 5. after recursively updating the binaries and arriving at target version , run the python stats script again.
