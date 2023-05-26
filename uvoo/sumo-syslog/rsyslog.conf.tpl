$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat

$RepeatedMsgReduction on

# $Fileowner syslog
# $FileGroup adm
# $FileCreateMode 0640
# $DirCreateMode 0755
# $Umask 0022
# $PrivDropToUser syslog
# $PrivDropToGroup syslog

$WorkDirectory /var/spool/rsyslog

# $IncludeConfig /etc/rsyslog.d/*.conf


$ModLoad imudp.so
$UDPServerRun 8514
$ModLoad imtcp.so
$InputTCPServerRun 8514
{% if LOG_TO_VAR_LOG_HOSTS is defined  -%}
  {% if LOG_TO_VAR_LOG_HOSTS == "true" -%}
$template DynamicFile,"/var/log/hosts/%HOSTNAME%/%syslogfacility-text%.log"
*.*    -?DynamicFile
  {%- endif %}
{%- endif %}
{% if LOG_TO_STDOUT is defined  -%}
  {% if LOG_TO_STDOUT == "true" -%}
*.* -/dev/stdout
  {%- endif %}
{%- endif %}


$InputTCPServerKeepAlive on
$DefaultNetstreamDriverCAFile /etc/rsyslog.d/digicert_ca.crt


template(name="SumoFormat" type="string" string="<%pri%>%protocol-version% %timestamp:::date-rfc3339% %HOSTNAME% %app-name% %procid% %msgid% {{ SUMO_TOKEN }} %msg%\n")


action(type="omfwd"
    protocol="tcp"
    target="{{ TARGET }}"
    port="6514"
    template="SumoFormat"
    StreamDriver="gtls"
    StreamDriverMode="1"
    StreamDriverAuthMode="x509/name"
    StreamDriverPermittedPeers="{{ PERMITTED_PEERS }}")


# TLS
# include(
#    file="/etc/rsyslog.d/rsyslog-tls.conf"
#    mode="optional"
# )

# $ModLoad imtcp
# $DefaultNetstreamDriver gtls
# defaultNetstreamDriverCAFile="/etc/rsyslog.d/t.ca"
# defaultNetstreamDriverCertFile="/etc/rsyslog.d/t.crt"
# defaultNetstreamDriverKeyFile="/etc/rsyslog.d/t.key"


# $InputTCPServerStreamDriverAuthMode x509/name
# $InputTCPServerStreamDriverMode 1
# $InputTCPServerRun 6514
# END TLS
