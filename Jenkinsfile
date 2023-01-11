properties([parameters([string(defaultValue: '10.44.1.160', name: 'dxEngineAddress', trim: true), choice(choices: ['6.0.14.0', '6.0.15.0', '6.0.16.0', '6.0.17.0'], name: 'dxVersion'), string(name: 'sourceName', trim: true), string(name: 'templateName', trim: true)])])
pipeline { 
    agent any 
    environment { 
        SECRET_CREDS = credentials('fwdview-delphix-credentials')
    }
    stages { 
        stage('Git Checkout') {
            steps {
                bat 'rmdir /s /q delphix_create_containers';
                bat 'git clone https://github.com/cameronbose/delphix_create_containers.git';
            }
        }
        
        stage('Creating Containers') { 
            steps {
                bat "python createContainer.py ${params.dxVersion} ${params.dxEngineAddress} ${SECRET_CREDS_USR} ${SECRET_CREDS_PSW} ${params.templateName} ${params.sourceName}";    
            }
        } 
    }
    post { 
        always { 
            echo "this will always run!"; 
        }
        success { 
            echo "Containers successfully Created!"; 
        } 
        failure { 
            echo "Failed - please look at the error logs."; 
        } 
        unstable { 
            echo "Jenkins run was unstable, please check logs."; 
        } 
        changed { 
            echo "Creating containers is now successful!"; 
            
        }
    }
}
