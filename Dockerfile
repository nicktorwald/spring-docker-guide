FROM maven:3.6.3-openjdk-11 AS java-builder

ENV MAVEN_OPTS -XX:+TieredCompilation -XX:TieredStopAtLevel=1

WORKDIR /source
COPY pom.xml .
RUN mvn --threads 1C --errors --batch-mode dependency:resolve-plugins dependency:go-offline
COPY src ./src
RUN mvn --threads 1C --errors --batch-mode --offline package
RUN mkdir target/_output \
    && cd target/_output \
    && mv ../*.jar ./app.jar \
    && java -Djarmode=layertools -jar app.jar extract

# ---

FROM openjdk:11-jre

LABEL maintainer="nicktorwald"

COPY distribution/boot-ready.sh /usr/local/bin/
COPY distribution/launch.sh /usr/local/bin/

ENV APP_ROOT /opt/dice-roller-service

RUN groupadd --gid 999 --system dice-roller \
    && useradd --uid 999 --system --gid dice-roller dice-roller \
    && mkdir --parents ${APP_ROOT} \
    && chown --recursive dice-roller:dice-roller ${APP_ROOT}

WORKDIR ${APP_ROOT}
COPY --from=java-builder /source/target/_output/dependencies/ ./
COPY --from=java-builder /source/target/_output/spring-boot-loader/ ./
COPY --from=java-builder /source/target/_output/snapshot-dependencies/ ./
COPY --from=java-builder /source/target/_output/application/ ./

EXPOSE 8080/tcp

HEALTHCHECK CMD ["boot-ready.sh"]

ENV EXECUTABLE org.springframework.boot.loader.JarLauncher
ENV JAVA_OPTS -Xms512m -Xmx512m

USER dice-roller
ENTRYPOINT ["launch.sh"]
CMD ["--spring.profiles.active=point-dice"]
