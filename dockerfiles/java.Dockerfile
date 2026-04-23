FROM claude-code-base

USER root

ARG MAVEN_VERSION=3.9.9

ENV JAVA_HOME=/opt/java \
    MAVEN_HOME=/opt/maven \
    PATH=/opt/java/bin:/opt/maven/bin:${PATH}

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && arch="$(dpkg --print-architecture)" \
    && case "$arch" in \
         amd64) jdk_arch=x64 ;; \
         arm64) jdk_arch=aarch64 ;; \
         *) echo "Unsupported arch: $arch" >&2; exit 1 ;; \
       esac \
    && mkdir -p /opt/java /opt/maven \
    && curl -fsSL "https://api.adoptium.net/v3/binary/latest/24/ga/linux/${jdk_arch}/jdk/hotspot/normal/eclipse" -o /tmp/jdk.tar.gz \
    && tar -xzf /tmp/jdk.tar.gz -C /opt/java --strip-components=1 \
    && rm /tmp/jdk.tar.gz \
    && curl -fsSL "https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" -o /tmp/maven.tar.gz \
    && tar -xzf /tmp/maven.tar.gz -C /opt/maven --strip-components=1 \
    && rm /tmp/maven.tar.gz \
    && rm -rf /var/lib/apt/lists/*

USER node
