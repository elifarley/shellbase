# 15-dev-tools.sh: Development tool helpers
# Maven: mvnprop, mvndep
# Gradle: gradle.dep
# SmartCTL: smartctl alias

# path_prepend (11-functions.sh) handles dedup + existence check.
# If not loaded (e.g. sourcing this file standalone), run: source ~/.bashrc

# Go SDK (managed by Go toolchain)
path_prepend "$HOME/go/bin"
path_prepend "$HOME/sdk/go1.26.1/bin"

# Google Cloud SDK
path_prepend "$HOME/google-cloud-sdk/bin"
[ -r "$HOME/google-cloud-sdk/completion.bash.inc" ] && . "$HOME/google-cloud-sdk/completion.bash.inc"

# SmartCTL
alias smartctl='smartctl -s on -i -A -f brief -f hex,id -l devstat'

# Maven

# Old version using help:evaluate (kept for reference)
mvnprop_old() {
  local prop="$1"; shift
  mvn 2>/dev/null help:evaluate -q -DforceStdout -Dexpression="$prop" "$@" \
  && echo
}

# Get Maven property value using echo-maven-plugin
mvnprop() {
  local prop="$1"; shift
  MAVEN_OPTS="$MAVEN_OPTS -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn" \
    mvn 2>/dev/null -B com.github.ekryd.echo-maven-plugin:echo-maven-plugin:echo -Decho.message='${'"$prop"'}' "$@" \
      | grep -A1 echo-maven-plugin | grep -v -- '--' | grep -v echo-maven-plugin | cut -d' ' -f2-
}

# Show Maven dependency tree
mvndep() {
  local dep="$1"; shift
  MAVEN_OPTS="$MAVEN_OPTS -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn" \
    mvn 2>&1 -B dependency:tree ${dep:+-Dincludes="$dep"} "$@" \
    | sed -rn '/\[INFO\] --- /,/Reactor Summary for / s/\[INFO\] //p' | head -n-1
}

# Gradle dependency insight
gradle.dep() (
  local dep="${1:?Please specify dependency to be checked}"; shift
  set -x
  ./gradlew 2>&1 :dependencyInsight --configuration compileClasspath \
    ${dep:+--dependency="$dep"} "$@"
)
