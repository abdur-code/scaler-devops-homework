FROM eclipse-temurin:21-jdk-alpine AS build

WORKDIR /src
COPY Hello.java ./
RUN javac Hello.java

# the compiler is only needed above, so the final image ships the JRE only
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app
COPY --from=build /src/Hello.class ./

EXPOSE 8080
CMD ["java", "Hello"]
