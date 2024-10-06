FROM iamdevopstrainer/tomcat:base
COPY target/ABCtechnologies-1.0.war /usr/local/tomcat/webapps/
CMD ["catalina.sh", "run"]
