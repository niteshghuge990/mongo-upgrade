#!/bin/bash  
# this script will stop mongod process , backup conf file ,uninstall the old version of mongodb ,
# replace the mongo version in yum repos and install , and put back the old configuration and update the compatibility to later one
export MONGO_ADMIN_PASS=gopro
export MONGO_ADMIN_USER=mongoProdUser
mkdir logs
MONGO_ADMIN_PASS=`python /ushurapp/getDynamicPasswords.py platform | grep 'MONGO_PASSWORD='|cut -f1 | cut -d '=' -f2`
export DB_URI='mongodb://'$MONGO_ADMIN_USER':'$MONGO_ADMIN_PASS'@localhost:57017/'
mongo  --authenticationDatabase=admin -p $MONGO_ADMIN_PASS -u $MONGO_ADMIN_USER --port 57017 --eval 'db.runCommand( { ping: 1 } )'
if [ $? -ne 0 ]; then
  mongosh  --authenticationDatabase=admin -p $MONGO_ADMIN_PASS -u $MONGO_ADMIN_USER --port 57017 --eval 'db.runCommand( { ping: 1 } )'
  if [ $? -ne 0 ]; then
    exit 1
  fi
fi
#install python requirements.txt for db stats python script
python3 -m venv env
if [ $? -ne 0 ]; then
  echo "`date` virtual environment not set"
  exit 1
fi
source env/bin/activate
python3 -m pip install -r ./requirements.txt
if [ $? -ne 0 ]; then
  echo "`date` could not install pymongo"
  exit 1
fi
echo "`date` executing db stats script"
python3 ./db-stats-finder.py
if [ $? -ne 0 ]; then
  echo "`date` could not execute stats script"
  exit 1
fi
echo "`date` completed db stats script for v3.4"

## create AMI of instance  ::::: To be done/supervised by DevOps
sudo cp /etc/mongod.conf /etc/mongod.conf.bkp
if [ $? -ne 0 ]; then
  echo "`date` could not backup mongo.conf"
  exit 1
fi
sudo mv /etc/yum.repos.d/mongodb-org-3.4.repo /etc/yum.repos.d/mongodb-org.repo

ping_mongo_cmd(){
  echo "using mongo cmd for ping"
  count=0
  while ! mongo  --authenticationDatabase=admin -p $MONGO_ADMIN_PASS -u $MONGO_ADMIN_USER --port 57017 --eval 'db.runCommand( { ping: 1} )'
  do
    echo "`date` waiting $count*10 seconds"
    if [ $count -gt 11 ]; then
      echo "`date` could not start mongod $1"
      exit 1
    fi
  ((count=count+1))
  echo "`date` waiting for mongodb $1 to come up,retrying in 10s"
  sleep 10
  done
}

ping_mongosh_cmd(){
  echo "using mongosh for ping"
  count=0
  while ! mongosh  --authenticationDatabase=admin -p $MONGO_ADMIN_PASS -u $MONGO_ADMIN_USER --port 57017 --eval 'db.runCommand( { ping: 1} )'
  do
    echo "`date` waiting $count*10 seconds"
    if [ $count -gt 11 ]; then
      echo "`date` could not start mongod $1"
      exit 1
    fi
    ((count=count+1))
    echo "`date` waiting for mongodb $1 to come up,retrying in 10s"
    sleep 10
  done
}
set_compatibility_feature_with_mongosh_cmd(){
  mongosh  --authenticationDatabase=admin -p $MONGO_ADMIN_PASS -u $MONGO_ADMIN_USER --port 57017 --eval 'db.adminCommand( { setFeatureCompatibilityVersion: "'$1'" } )'
  if [ $? -ne 0 ]; then
      echo "`date` could not set feature compatibile version $1 ,exitting !!"
      exit 1    
  fi
}

set_compatibility_feature_with_mongo_cmd(){
  mongo  --authenticationDatabase=admin -p $MONGO_ADMIN_PASS -u $MONGO_ADMIN_USER --port 57017 --eval 'db.adminCommand( { setFeatureCompatibilityVersion: "'$1'" } )'
  if [ $? -ne 0 ]; then
      echo "`date` could not set feature compatibile version $1 ,exitting !!"
      exit 1    
  fi
}
update_mongodb_version(){
    use_mongo_sh=false
    if [ "5.0" == "$1" ] ; then
        use_mongo_sh=true
    fi
    echo "using '$use_mongo_sh' for '$1'"
    if $use_mongo_sh
    then
      ping_mongosh_cmd $1
    else
      ping_mongo_cmd $1
    fi
    echo "`date` stopping mongodb" && \
    sudo systemctl stop mongod && \
    echo "`date` stopped mongodb $1" && \
    sudo yum erase $(rpm -qa | grep mongodb-org) -y && \
    echo "`date` removed mongodb $1" && \
    sudo sed -i "s/$1/$2/g" /etc/yum.repos.d/mongodb-org.repo && \
    echo "`date` updated mongodb yum repo" && \
    sudo yum install -y mongodb-org && \
    echo "`date` mongodb installation completed for $2" && \
    sudo cp /etc/mongod.conf.bkp /etc/mongod.conf && \
    echo "`date` updated mongodb conf file" && \
    sudo chown mongod:mongod /etc/mongod.conf && \
    echo "`date` updated mongodb ownership" && \
    echo "`date` starting mongodb $2" && \
    sudo systemctl start mongod
    if [ $? -ne 0 ]; then
        echo "`date` could not start mongod $2"
        exit 1
    fi


    if $use_mongo_sh
    then
      ping_mongosh_cmd $2
    else
      ping_mongo_cmd $2
    fi

    sudo cp /var/log/mongodb/mongod.log logs/$1-$2.log && \
    echo "`date` started mongodb $2 process" && \
    if $use_mongo_sh
    then
      echo "using mongosh for compatibilty"
      set_compatibility_feature_with_mongosh_cmd $2
    else
      echo "using mongo for compatibilty"
      set_compatibility_feature_with_mongo_cmd $2
    fi
    echo "`date` updated mongodb feature compatibility version to $2" && \
    sudo systemctl stop mongod && \
    sudo systemctl start mongod && \
    echo "`date` Upgraded to mongo $2"
    
}

echo "`date` starting 3.4 - 3.6"
update_mongodb_version "3.4" "3.6"
echo "`date` completed 3.4 - 3.6"
echo "`date` starting 3.6 - 4.0"
update_mongodb_version "3.6" "4.0"
echo "`date` completed 3.6 - 4.0"
echo "`date` starting 4.0 - 4.2"
update_mongodb_version "4.0" "4.2"
echo "`date` completed 4.0 - 4.2"
echo "`date` starting 4.2 - 4.4"
update_mongodb_version "4.2" "4.4"
echo "`date` completed 4.2 - 4.4"
echo "`date` starting 4.4 - 5.0"
update_mongodb_version "4.4" "5.0"
echo "`date` completed 4.4 - 5.0"
echo "`date` starting 5.0 - 6.0"
update_mongodb_version "5.0" "6.0"
echo "`date` completed 5.0 - 6.0"
echo "`date` Completed, starting mongodb server v6.0"
ping_mongosh_cmd "5.0"
if [ $? -ne 0 ]; then
    echo "`date` could not start mongod 6.0"
    exit 1
fi
echo "`date` executing db stats script"
python3 ./db-stats-finder.py