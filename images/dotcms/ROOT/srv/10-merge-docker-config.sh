#!/bin/bash

set -e

source /srv/utils/discovery-include.sh
source /srv/utils/config-defaults.sh

echo "Merge Docker Config ...."
# Overwrite Tomcat files
cd /srv/templates/tomcat/OVERRIDE
for OVERRIDEFILE in $(find . -type f); do
    [[ ! -d "${TOMCAT_HOME}/$(dirname $OVERRIDEFILE)" ]] && mkdir -p "${TOMCAT_HOME}/$(dirname $OVERRIDEFILE)"
    cp "$OVERRIDEFILE" "${TOMCAT_HOME}/$OVERRIDEFILE"
    
    # TODO: Hazelcast session store
    #[[ "$(basename $file)" == "hazelcast-client.xml" ]] && cp $file /srv/bin/system/src-conf/

    # feed to Dockerize for templating
    echo "${TOMCAT_HOME}/$OVERRIDEFILE" >>/srv/config/templatable.txt

done

# Overwrite dotCMS app files
cd /srv/templates/dotcms/OVERRIDE
for OVERRIDEFILE in $(find . -type f); do
    echo $OVERRIDEFILE
    [[ ! -d "${TOMCAT_HOME}/webapps/ROOT/$(dirname $OVERRIDEFILE)" ]] && mkdir -p "${TOMCAT_HOME}/webapps/ROOT/$(dirname $OVERRIDEFILE)"

    if [[ "$(basename $OVERRIDEFILE)" == "hazelcast-client.xml" ]]; then
        cp "$OVERRIDEFILE" /srv/bin/system/src-conf/hazelcast-client.xml
        echo "/srv/bin/system/src-conf/hazelcast-client.xml" >>/srv/config/templatable.txt
        #echo "/srv/bin/system/src-conf/hazelcast-client.xml" >>/srv/container-config/templatable.txt
    fi

    cp "$OVERRIDEFILE" "${TOMCAT_HOME}/webapps/ROOT/$OVERRIDEFILE"

    # feed to Dockerize for templating
    echo "${TOMCAT_HOME}/webapps/ROOT/$OVERRIDEFILE" >>/srv/config/templatable.txt

done


# Merge dotCMS properties diffs
cd /srv/templates/dotcms/CONF
for MERGEFILE in $(find . -type f); do
    echo "Merging $MERGEFILE"
    RUNFILE="${TOMCAT_HOME}/webapps/ROOT/WEB-INF/classes/$(basename $MERGEFILE)"
    SRCFILE="/srv/bin/system/src-conf/$(basename $MERGEFILE)"

    for varname in $(grep -oP "^\K[[:alnum:]].*(?=\=)" "$MERGEFILE"); do
        escaped_varname=$(escapeRegexChars "$varname")
        echo "Resetting '$varname'"
        sed -ri "s/^(${escaped_varname})\s*=(.*)$/#\1=\2/" "$RUNFILE"
        sed -ri "s/^(${escaped_varname})\s*=(.*)$/#\1=\2/" "$SRCFILE"
    done
    sed -i 's/\\/\\\\/g' "$RUNFILE"
    sed -i 's/\\/\\\\/g' "$MERGEFILE"

    config_injection=$(<"$MERGEFILE")

    prefile=$(sed '/##\ BEGIN\ PLUGINS/Q' "$RUNFILE")
    postfile=$(sed -ne '/##\ BEGIN\ PLUGINS/,$ p' "$RUNFILE")
    echo -e "${prefile}\n${config_injection}\n\n\n${postfile}" >"$RUNFILE"

    prefile=$(sed '/##\ BEGIN\ PLUGINS/Q' "$SRCFILE")
    postfile=$(sed -ne '/##\ BEGIN\ PLUGINS/,$ p' "$SRCFILE")
    echo -e "${prefile}\n${config_injection}\n\n\n${postfile}" >"$SRCFILE"

    # feed to Dockerize for templating
    echo "$RUNFILE" >>/srv/config/templatable.txt

done


