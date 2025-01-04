# EC2-CodePipeline
Orchestrate Code build and Code deploy through code pipeline to give CI to EC2 from Github as VCS

# Manual intervensions

Successful deployment from CodePipeline side, 

# ssh commands 
# a) if first deployment : 
    1) cd /var/www/myapp
    2) source /var/www/myapp/venv/bin/activate
    3) pip install flask
    4) python3 app.py

# b) if Subsequent deployment
    1) cd /opt/codedeploy-agent/deployment-root
    2) ls
    3) cd <unique-folder>
    4) ls 
    5) cd <deployment-id>
    6) ls
    7) cd deployment-archive
    8) sudo unzip -o app.zip -d /var/www/myapp
    9) repeat #a
