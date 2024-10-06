FROM iamdevopstrainer/tomcat:base
COPY /var/lib/jenkins/workspace/industry-grade-project-i/target/*.war /usr/local/tomcat/webapps/
CMD ["catalina.sh", "run"]
