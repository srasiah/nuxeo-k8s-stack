FROM jenkins/jenkins:2.489-jdk21

USER root

# Skip setup wizard
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

USER jenkins

# Install plugins
RUN jenkins-plugin-cli --plugins \
    kubernetes:4336.v97b_e22d9cf39 \
    workflow-aggregator:600.vb_57cdd26fdd7 \
    git:5.7.2 \
    configuration-as-code:1909.vb_b_c3d2ecaff \
    credentials-binding:706.v12f8c6f62ed2 \
    job-dsl:1.98 \
    docker-workflow:587.v61f0700d4c8a \
    pipeline-stage-view:2.34 \
    blueocean:1.27.15 \
    kubernetes-cli:1.12.1 \
    gitlab-plugin:1.9.2

# Optional: Add JCasC configuration
# COPY jenkins.yaml /var/jenkins_home/jenkins.yaml
# ENV CASC_JENKINS_CONFIG=/var/jenkins_home/jenkins.yaml
