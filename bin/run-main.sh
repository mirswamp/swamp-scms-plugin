#! /bin/bash
#  SWAMP SCMS Hooks
#
#  Copyright 2016 Jared Sweetland, Vamshi Basupalli, James A. Kupsch
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

#set -x -v

HOME=${HOME:-~}
#printenv
#echo ~
DIRNAME=${0%/*};
DIRNAME=${DIRNAME%/*};
#echo $DIRNAME
function main() {

	local MAIN_CLASS="$1"; shift

	### Jeff Gaynor dependencies 

	CLASSPATH=$HOME/.m2/repository/edu/uiuc/ncsa/security/ncsa-security-util/3.3-SNAPSHOT/ncsa-security-util-3.3-SNAPSHOT.jar:$HOME/.m2/repository/commons-codec/commons-codec/1.4/commons-codec-1.4.jar:$HOME/.m2/repository/edu/uiuc/ncsa/security/ncsa-security-servlet/3.3-SNAPSHOT/ncsa-security-servlet-3.3-SNAPSHOT.jar:$HOME/.m2/repository/edu/uiuc/ncsa/security/ncsa-security-core/3.3-SNAPSHOT/ncsa-security-core-3.3-SNAPSHOT.jar:$HOME/.m2/repository/commons-configuration/commons-configuration/1.7/commons-configuration-1.7.jar:$HOME/.m2/repository/commons-digester/commons-digester/1.8.1/commons-digester-1.8.1.jar:$HOME/.m2/repository/javax/inject/javax.inject/1/javax.inject-1.jar:$HOME/.m2/repository/log4j/log4j/1.2.17/log4j-1.2.17.jar:$HOME/.m2/repository/org/apache/httpcomponents/httpclient/4.3.2/httpclient-4.3.2.jar:$HOME/.m2/repository/commons-logging/commons-logging/1.1.3/commons-logging-1.1.3.jar:$HOME/.m2/repository/org/apache/httpcomponents/httpcore/4.3.2/httpcore-4.3.2.jar:$HOME/.m2/repository/net/sf/json-lib/json-lib/2.4/json-lib-2.4-jdk15.jar:$HOME/.m2/repository/commons-beanutils/commons-beanutils/1.8.0/commons-beanutils-1.8.0.jar:$HOME/.m2/repository/commons-collections/commons-collections/3.2.1/commons-collections-3.2.1.jar:$HOME/.m2/repository/commons-lang/commons-lang/2.5/commons-lang-2.5.jar:$HOME/.m2/repository/net/sf/ezmorph/ezmorph/1.0.6/ezmorph-1.0.6.jar:$HOME/.m2/repository/edu/uiuc/ncsa/security/ncsa-security-storage/3.3-SNAPSHOT/ncsa-security-storage-3.3-SNAPSHOT.jar:$HOME/.m2/repository/org/apache/httpcomponents/httpmime/4.3.1/httpmime-4.3.1.jar:$HOME/.m2/repository/edu/uiuc/ncsa/swamp/ncsa-swamp/1.0-SNAPSHOT/ncsa-swamp-1.0-SNAPSHOT.jar
	
	### Swamp API client dependencies
	CLASSPATH="$CLASSPATH:$HOME/.m2/repository/commons-cli/commons-cli/1.3/commons-cli-1.3.jar:$DIRNAME/bin/swamp-api-client-1.0-SNAPSHOT.jar"

	java -cp $CLASSPATH $MAIN_CLASS "$@"

}

main edu.wisc.cs.swamp.Cli "$@"
#echo "exit-code" $?
