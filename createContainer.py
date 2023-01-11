import sys 
import os 
import time
import json

versionDict = {'6.0.14.0':'1.11.14','6.0.15.0':'1.11.15','6.0.16.0':'1.11.16','6.0.17.0':'1.11.17'}

def getAPIVersion(delphixVersion):
    apiVersion = versionDict[delphixVersion]
    major,minor,micro = apiVersion.split('.')
    return major,minor,micro 

vdbFile = open("vdbNames.txt", "r").read().splitlines()
vdbList = [i.strip() for i in vdbFile]

def getVDBContainerID(vdbName): 
    APIQuery = os.popen('curl -X GET -k http://10.44.1.160/resources/json/delphix/database -b "cookies.txt" -H "Content-Type: application/json"').read()
    queryDict = json.loads(APIQuery) 
    for db in queryDict["result"]:
        if db['name'] == vdbName: 
            vdbContainerReference = db['reference']
    return vdbContainerReference

def getTemplateID(templateName): 
    APIQuery = os.popen('curl -X GET -k http://10.44.1.160/resources/json/delphix/selfservice/template -b "cookies.txt" -H "Content-Type: application/json"').read()
    queryDict = json.loads(APIQuery) 
    for db in queryDict["result"]:
        if db['name'] == templateName: 
            templateReference = db['reference']
    return templateReference 

if __name__ == "__main__": 
    
    version = sys.argv[1] 
    dxEngine = sys.argv[2] 
    username = sys.argv[3] 
    password = sys.argv[4] 
    templateName = sys.argv[5]  
    sourceName = sys.argv[6]
    
    major,minor,micro = getAPIVersion(delphixVersion)

    print("logging in...")
    os.system(f"sh login.sh {username} {password} {dxEngine} {major} {minor} {micro}")
    templateReference = getTemplateID(templateName)

    for vdbName in vdbList: 
        while True:
            try: 
                vdbContainerReference = getVDBContainerID(vdbName)
                os.system(f'sh createContainer.sh -n "{sourceName}" {vdbName} {vdbContainerReference} {templateReference}')
                time.sleep(30)
            except KeyError: 
                print("Waiting for VDB to be provisioned...")
                time.sleep(60)
                continue
            break 
