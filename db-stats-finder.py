from pymongo import MongoClient
from pymongo.errors import ConnectionFailure,InvalidURI,ServerSelectionTimeoutError
import socket
import csv
import os


def mongo_collection_count(client,db_version):
    print('recieved connectioned')
    dbs = client.list_database_names()
    db_collections = {}
    for db in dbs:
        if db != 'config':
            dbCon = client[db]
            for collection in dbCon.list_collection_names():
                coll_name = db+'-'+collection
                coll_count = dbCon[collection].count()
                db_collections[coll_name] = coll_count
    file_type  = 'collection-'+db_version
    print('extracted collection info')
    export_to_csv(db_collections,file_type)

def db_stats(client,db_version):
    dbs = client.list_database_names()
    db_stat = {}
    for db in dbs:
        dbCon = client[db]
        stats = dbCon.command('dbstats')
        for key in stats.keys():
            db_stat[db+'-'+key] = stats[key]
    print('extracted database stats')
    file_type  = 'database-'+db_version
    export_to_csv(db_stat,file_type)

def export_to_csv(collection_counts,type):
    print(f"""type {type}""")
    hostname = socket.gethostname()
    with open(type+'-'+hostname+'.csv', 'w') as csv_file:
        header = ['name','count']
        writer = csv.writer(csv_file)
        writer.writerow(header)
        for key, value in collection_counts.items():
            writer.writerow([key, value])
def get_db_version(client):
     return client.db.command({'buildInfo':1})['version']
def main():
    uri = os.getenv('DB_URI')
    db_version = ""
    client = None
    if uri is not None:
        try:
            client = MongoClient(os.getenv('DB_URI'))
            db_version = get_db_version(client)
        except (ConnectionFailure,InvalidURI,ServerSelectionTimeoutError) as e:
            raise Exception(f"""Mongodb Connection cannot be established on URI {uri}""",e)
        except Exception as e:
             raise Exception(f"""Faced exception in db version check {e}""")
        print(f"""db version {db_version}""")
        try:            
            print('generating collection count')
            mongo_collection_count(client,db_version)
        except Exception as e:
             raise Exception(f"""Faced exception in collection count generation {e}""")
        print('collection count generation completed')
        try:
            print('generating db stats')
            db_stats(client,db_version)
        except Exception as e:
             raise Exception(f"""Faced exception in database stats generation {e}""")
        print('db stats generation completed1')
    else:
        print(f"""Expecting mongodb connection URI in format mongodb://user:password@ip:port/""")
if __name__ == '__main__':
    main()
    