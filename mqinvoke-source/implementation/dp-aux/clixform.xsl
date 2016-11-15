<?xml version="1.0" encoding="UTF-8" ?>
<!--
  Licensed Materials - Property of IBM
  IBM WebSphere DataPower Appliances
  Copyright IBM Corporation 2007, 2014. All Rights Reserved.
  US Government Users Restricted Rights - Use, duplication or disclosure
  restricted by GSA ADP Schedule Contract with IBM Corp.
-->

<!--
/*
 *
 *   Copyright (c) 2002-2003 DataPower Technology, Inc. All Rights Reserved
 *
 * THIS IS UNPUBLISHED PROPRIETARY TRADE SECRET SOURCE CODE OF DataPower
 * Technology, Inc.
 *
 * The copyright above and this notice must be preserved in all copies of
 * the source code. The copyright notice above does not evidence any actual
 * or intended publication of such source code. This source code may not be
 * copied, compiled, disclosed, distributed, demonstrated or licensed except
 * as expressly authorized by DataPower Technology, Inc.
 *
 */
-->

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:dpgui="http://www.datapower.com/extensions/webgui"
    xmlns:dpe="http://www.datapower.com/extensions"
    xmlns:dpfunc="http://www.datapower.com/extensions/functions"
    xmlns:func="http://exslt.org/functions"
    xmlns:regexp="http://exslt.org/regular-expressions"
    extension-element-prefixes="dpe func regexp"
    exclude-result-prefixes="dpgui">

    <!-- this file contains the stylesheets which convert XML to CLI scripts -->

    <xsl:include href="SchemaUtil.xsl"/>

    <xsl:output method="text" encoding="utf-8" indent="yes"/>

    <!-- Note this is for compilation purposes only.  The real sessionid
         is set in main.xsl, modify.xsl and drMgmtInterface.xsl.  Therefore,
         you must always import (not include) clixform.xsl
    <xsl:variable name="sessionid" select="'undefined-in-clixform'"/>
    -->

    <func:function name="dpfunc:if-then-else">
        <xsl:param name="condition" />
        <xsl:param name="ifValue" />
        <xsl:param name="elseValue"></xsl:param>

        <xsl:choose>
            <xsl:when test="$condition">
                <func:result select="$ifValue" />
            </xsl:when>
            <xsl:otherwise>
                <func:result select="$elseValue" />
            </xsl:otherwise>
        </xsl:choose>
    </func:function>

    <xsl:variable name="eol">
        <xsl:text>&#xA;</xsl:text>
    </xsl:variable>

    <xsl:variable name="quote">
        <xsl:text>"</xsl:text>
    </xsl:variable>

    <!-- for dynamic config generation, we need to know if an object already exists,
         so it can be deleted first.  When we're generating a startup-config script,
         however, we never do this.  So the solution is to fetch the current config only
         when we're doing dynamic config, and leave this an empty node-set otherwise. -->

    <!-- we are doing a delta, as opposed to generating an entire config
         as used by 'show running config' and 'show mem' -->
    <!-- default to false for use by dpe:transform calls to clixform
         Overridden in map by http-request-header on map request -->
    <xsl:variable name="delta-config" select="false()" />

   <!-- The configuration comes from an outside the appliance's configuration,
        such as by import-package or a remote domain configuration -->
   <!-- default to false for use by dpe:transform calls to clixform
         Overridden in map by checking external-config element in map request -->
    <xsl:variable name="EXTERNAL-CONFIG" select="false()" />

    <xsl:variable name="cli-existing">
        <!-- in either save-config or show-config mode, don't generate 'no' statements -->
        <xsl:if test="($delta-config=true())">
            <xsl:choose>
                <xsl:when test="function-available('dpgui:get-config')">
                    <xsl:call-template name="do-mgmt-request">
                        <xsl:with-param name="request">
                            <request>
                              <operation type="get-config"/>
                            </request>
                        </xsl:with-param>
                    </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message dpe:type="mgmt" dpe:priority="warn" dpe:id="{$DPLOG_WEBGUI_SIMULATINGGETCONFIG}"/>
                    <!-- for debugging delta updates with xj:
                         use a request document as input (see debug/request.xml)
                         and retrieve a canned 'cli-existing' file here -->
                         <xsl:copy-of select="document('/debug/cfg.xml')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
    </xsl:variable>

    <!-- for use with 'show running-config', 'write-mem' from CLI
         and save-config from WebGUI -->
    <xsl:template match="/" priority="-100">
      <xsl:value-of select="concat('top; configure terminal;', $eol, $eol)"/>
      <xsl:apply-templates mode="cli-object" select="*"/>
    </xsl:template>

    <!-- utility template -->
    <xsl:template mode="cli-object" match="configuration">
        <xsl:call-template name="version-comment"/>
        <xsl:apply-templates mode="cli-object" select="*"/>
    </xsl:template>

    <xsl:template name="version-comment">
        <!-- context node is /configuration -->
        <xsl:if test="(@build and @timestamp)">
            <xsl:text># configuration generated </xsl:text>
            <xsl:value-of select="normalize-space(@timestamp)"/>
            <xsl:text>; firmware version </xsl:text>
            <xsl:value-of select="concat(normalize-space(@build), $eol)"/>
        </xsl:if>
    </xsl:template>

    <!-- ======== cli-object and cli-delete-object templates begin here ======== -->

    <!-- Save the EthernetInterface object both in the standard way and in the legacy way -->
    <!-- the legacy EthernetInterface object did not have %if%s -->
    <xsl:template mode="cli-object" match="EthernetInterface">
        <xsl:value-of select="concat($eol, '%if% unavailable &quot;link-aggregation&quot;', $eol)" />
        <xsl:value-of select="concat('# Just enough legacy interface config to maintain connectivity on pre-link-aggregation firmware', $eol)" />
        <xsl:value-of select="concat('interface ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:value-of select="concat('  arp', $eol)"/>
        <xsl:value-of select="concat('  ipv6', $eol)"/>
        <xsl:apply-templates mode="LegacyEthernetInterface" select="."/>
        <xsl:value-of select="concat('  admin-state ',dpfunc:quoesc(mAdminState), $eol)"/>
        <xsl:value-of select="concat('exit ', $eol)"/>
        <xsl:value-of select="concat('%endif%', $eol)" />
        <xsl:value-of select="concat($eol, '%if% available &quot;link-aggregation&quot;', $eol)" />
        <xsl:value-of select="concat('%if% available &quot;ethernet&quot;')" />
        <xsl:apply-templates mode="CanonicalObject" select=".">
            <xsl:with-param name="noConditional" select="true()"/>
        </xsl:apply-templates>
        <xsl:value-of select="concat('%endif%', $eol)" />
        <xsl:value-of select="concat('%endif%', $eol)" />
    </xsl:template>

    <xsl:template mode="LegacyEthernetInterface" match="MTU">
        <xsl:value-of select="concat('  mtu ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="MACAddress">
        <xsl:value-of select="concat('  mac-address ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="Mode">
        <xsl:value-of select="concat('  mode ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="LegacyEthernetInterface" match="UseDHCP">
        <xsl:if test="(string(text()) = 'on')">
            <xsl:value-of select="concat('  dhcp', $eol)"/>
        </xsl:if>
    </xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="UseSLAAC">
        <xsl:if test="(string(text()) = 'on')">
            <xsl:value-of select="concat('  slaac', $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="LegacyEthernetInterface" match="IPAddress">
        <xsl:value-of select="concat('  ip address ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="SecondaryAddress">
        <xsl:value-of select="concat('  ip address ', dpfunc:quoesc(text()), ' secondary', $eol )"/>
    </xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="DefaultGateway">
        <xsl:value-of select="concat('  ip default-gateway ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="DefaultIPv6Gateway">
        <xsl:value-of select="concat('  ip default-ipv6-gateway ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="StaticRoutes">
        <xsl:value-of select="concat('  ip route ', dpfunc:quoesc(Destination), ' ', dpfunc:quoesc(Gateway), ' ', dpfunc:quoesc(Metric), $eol )"/>
    </xsl:template>

    <xsl:template mode="LegacyEthernetInterface" match="mAdminState"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="FlowControl"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="UseARP"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="UseIPv6"></xsl:template>

    <xsl:template mode="LegacyEthernetInterface" match="StandbyControl"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="Group"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="VirtualIP"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="Preempt"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="Priority"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="SelfBalance"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="Authentication"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="HelloTimer"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="SecondaryVirtualIP"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="HoldTimer"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="DistAlg"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="LinkAggMode"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="HardwareOffload"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="DADTransmits"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="DADRetransmitTimer"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="ApplyFlowControl"></xsl:template>
    <xsl:template mode="LegacyEthernetInterface" match="IPConfigMode"></xsl:template>


    <!-- Save the VLANInterface object both in the standard way and in the legacy way -->
    <!-- Only use the legacy way if link-aggregation is unavailable -->
    <xsl:template mode="cli-object" match="VLANInterface">
        <xsl:value-of select="concat($eol, '%if% unavailable &quot;link-aggregation&quot;', $eol)" />
        <xsl:value-of select="concat('%if% available &quot;vlan-sub-interface&quot;', $eol)" />
        <xsl:value-of select="concat('# Just enough legacy interface config to maintain connectivity on pre-link-aggregation firmware', $eol)" />
        <xsl:value-of select="concat('vlan-sub-interface ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:value-of select="concat('  arp', $eol)"/>
        <xsl:value-of select="concat('  ipv6', $eol)"/>
        <xsl:apply-templates mode="LegacyVLANInterface" select="."/>
        <xsl:value-of select="concat('exit ', $eol)"/>
        <xsl:value-of select="concat($eol, '%endif%', $eol)" />
        <xsl:value-of select="concat('%endif%', $eol)" />
        <xsl:value-of select="concat($eol, '%if% available &quot;link-aggregation&quot;', $eol)" />
        <xsl:value-of select="concat('%if% available &quot;vlan&quot;', $eol)" />
        <xsl:apply-templates mode="CanonicalObject" select=".">
            <xsl:with-param name="noConditional" select="true()"/>
        </xsl:apply-templates>
        <xsl:value-of select="concat($eol, '%endif%', $eol)" />
        <xsl:value-of select="concat('%endif%', $eol)" />
    </xsl:template>

    <xsl:template mode="LegacyVLANInterface" match="mAdminState">
        <xsl:value-of select="concat('  admin-state ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="Identifier">
        <xsl:value-of select="concat('  identifier ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="DefaultOutboundPriority">
        <xsl:value-of select="concat('  outbound-priority ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="EthernetInterface">
        <xsl:value-of select="concat('  interface ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="LegacyVLANInterface" match="UseDHCP">
        <xsl:if test="(string(text()) = 'on')">
            <xsl:value-of select="concat('  dhcp', $eol)"/>
        </xsl:if>
    </xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="UseSLAAC">
        <xsl:if test="(string(text()) = 'on')">
            <xsl:value-of select="concat('  slaac', $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="LegacyVLANInterface" match="IPAddress">
        <xsl:value-of select="concat('  ip address ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="SecondaryAddress">
        <xsl:value-of select="concat('  ip secondary-address ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="DefaultGateway">
        <xsl:value-of select="concat('  ip default-gateway ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="DefaultIPv6Gateway">
        <xsl:value-of select="concat('  ip default-ipv6-gateway ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="StaticRoutes">
        <xsl:value-of select="concat('  ip route ', dpfunc:quoesc(Destination), ' ', dpfunc:quoesc(Gateway), ' ', dpfunc:quoesc(Metric), $eol )"/>
    </xsl:template>

    <xsl:template mode="LegacyVLANInterface" match="MTU"></xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="OverType"></xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="LinkAggInterface"></xsl:template>

    <xsl:template mode="LegacyVLANInterface" match="UseARP"></xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="UseIPv6"></xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="DADTransmits"></xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="DADRetransmitTimer"></xsl:template>

    <xsl:template mode="LegacyVLANInterface" match="StandbyControl"></xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="Group"></xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="VirtualIP"></xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="Preempt"></xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="Priority"></xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="SelfBalance"></xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="Authentication"></xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="HelloTimer"></xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="SecondaryVirtualIP"></xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="HoldTimer"></xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="DistAlg"></xsl:template>
    <xsl:template mode="LegacyVLANInterface" match="IPConfigMode"></xsl:template>

    <!-- ************************************************************ -->
    <!-- CRLFetch -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-delete-object" match="CRLFetch"/>

    <xsl:template mode="cli-object" match="CRLFetch">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no crl' , $eol )"/>
                <xsl:apply-templates mode="CRLFetch"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="CRLFetch" match="CRLFetchConfig">
        <xsl:value-of select="concat('  crl ', dpfunc:quoesc(Name), ' ', dpfunc:quoesc(FetchType), $eol)"/>
        <xsl:apply-templates mode="CRLFetchConfig"/>
        <xsl:value-of select="concat('  exit', $eol)"/>
    </xsl:template>

    <xsl:template mode="CRLFetchConfig" match="IssuerValcred">
        <xsl:value-of select="concat('    issuer ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>

    <xsl:template mode="CRLFetchConfig" match="RefreshInterval">
        <xsl:value-of select="concat('    refresh ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>

    <xsl:template mode="CRLFetchConfig" match="DefaultStatus">
        <xsl:value-of select="concat('    default-status ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>

    <xsl:template mode="CRLFetchConfig" match="CryptographicProfile[text()!='']">
        <xsl:value-of select="concat('    ssl-profile ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>

    <xsl:template mode="CRLFetchConfig" match="SSLClientConfigType">
        <xsl:value-of select="concat('    ssl-client-type ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>

    <xsl:template mode="CRLFetchConfig" match="SSLClient">
        <xsl:value-of select="concat('    ssl-client ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>

    <xsl:template mode="CRLFetchConfig" match="URL[../FetchType='http']">
        <xsl:value-of select="concat('    fetch-url ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>

    <xsl:template mode="CRLFetchConfig" match="RemoteAddress[../FetchType='ldap']">
        <xsl:value-of select="concat('    remote-address ', dpfunc:quoesc(text()), ' ', dpfunc:quoesc(../RemotePort), $eol )"/>
    </xsl:template>

    <xsl:template mode="CRLFetchConfig" match="DN[../FetchType='ldap']">
        <xsl:value-of select="concat('    read-dn ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>

    <xsl:template mode="CRLFetchConfig" match="BindDN[../FetchType='ldap']">
        <xsl:value-of select="concat('    bind-dn ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>

    <xsl:template mode="CRLFetchConfig" match="BindPass[../FetchType='ldap']">
        <xsl:value-of select="concat('    bind-pass ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>

    <xsl:template mode="CRLFetchConfig" match="BindPassAlias[../FetchType='ldap']">
        <xsl:value-of select="concat('    bind-pass-alias ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>

    <xsl:template mode="CRLFetchConfig" match="LDAPVersion[../FetchType='ldap']">
        <xsl:value-of select="concat('    ldap-version ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>

    <xsl:template mode="CRLFetchConfig" match="LDAPReadTimeout[../FetchType='ldap']">
        <xsl:value-of select="concat('    ldap-readtimeout ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>

    <xsl:template mode="CRLFetchConfig" match="*"/>

    <!-- ************************************************************ -->
    <!-- TimeSettings -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-object" match="TimeSettings[LocalTimeZone]">

        <xsl:call-template name="available-open">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>

        <xsl:value-of select="concat($eol, 'timezone ', dpfunc:quoesc(LocalTimeZone))"/>
        <xsl:if test="(LocalTimeZone='Custom')">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(CustomTZName))"/>
            <xsl:if test="string(UTCDirection)">
                <xsl:value-of select="concat(' ', dpfunc:quoesc(UTCDirection))"/> 
            </xsl:if>
            <xsl:if test="string(OffsetHours)">
                <xsl:value-of select="concat(' ', dpfunc:quoesc(OffsetHours))"/>
            </xsl:if>
            <xsl:if test="string(OffsetMinutes)">
                <xsl:value-of select="concat(' ', dpfunc:quoesc(OffsetMinutes))"/>
            </xsl:if>
            <xsl:apply-templates mode="TimeSettings" select="."/>
        </xsl:if>
        <xsl:value-of select="$eol"/>

        <xsl:call-template name="available-close">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>

    </xsl:template>

    <xsl:template mode="TimeSettings" match="TimeSettings[DaylightOffsetHours >= 0]">
        <xsl:value-of select="concat(' ', dpfunc:quoesc(DaylightOffsetHours))"/>
        <xsl:if test="string(TZNameDST)">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(TZNameDST))"/>
        </xsl:if>
        <xsl:if test="string(DaylightStartMonth)">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(DaylightStartMonth))"/>
        </xsl:if>
        <xsl:if test="string(DaylightStartWeek)">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(DaylightStartWeek))"/>
        </xsl:if>
        <xsl:if test="string(DaylightStartDay)">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(DaylightStartDay))"/>
        </xsl:if>
        <xsl:if test="string(DaylightStartTimeHours)">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(DaylightStartTimeHours))"/>
        </xsl:if>
        <xsl:if test="string(DaylightStartTimeMinutes)">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(DaylightStartTimeMinutes))"/>
        </xsl:if>
        <xsl:if test="string(DaylightStopMonth)">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(DaylightStopMonth))"/>
        </xsl:if>
        <xsl:if test="string(DaylightStopWeek)">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(DaylightStopWeek))"/>
        </xsl:if>
        <xsl:if test="string(DaylightStopDay)">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(DaylightStopDay))"/>
        </xsl:if>
        <xsl:if test="string(DaylightStopTimeHours)">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(DaylightStopTimeHours))"/>
        </xsl:if>
        <xsl:if test="string(DaylightStopTimeMinutes)">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(DaylightStopTimeMinutes))"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="TimeSettings" match="TimeSettings"/>

    <!-- ************************************************************ -->
    <!-- StylePolicy -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-object" match="StylePolicy">
        <xsl:value-of select="concat($eol, 'stylepolicy ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:value-of select="concat('  reset', $eol)"/>
        <xsl:apply-templates mode="StylePolicy"/>
        <xsl:value-of select="concat('exit', $eol )"/>
    </xsl:template>

    <!-- if the rule is local, express it inline -->
    <xsl:template mode="StylePolicy" match="PolicyMaps">
        <xsl:variable name="configuration" select="../.."/>

        <!-- the name of the referenced rule -->
        <xsl:variable name="ruleName" select="Rule"/>
        <!-- referenced rule -->
        <xsl:variable name="theRule">
            <xsl:choose>
                <!-- first look in the context document -->
                <xsl:when test="($configuration/StylePolicyRule[@name=$ruleName])">
                    <xsl:copy-of select="$configuration/StylePolicyRule[@name=string($ruleName)]"/>
                </xsl:when>
                <!-- or if delta-config, look for existing object -->
                <xsl:when test="($delta-config)">
                    <xsl:copy-of select="$cli-existing//configuration/StylePolicyRule[@name=$ruleName]"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>

        <xsl:choose>
            <!-- if local -->
            <xsl:when test="($theRule/StylePolicyRule/@local='true')">
                <!-- inline rule definition -->
                <xsl:value-of select="concat('  ', $theRule/StylePolicyRule/Direction, ' ', dpfunc:quoesc(Match), $eol)"/>

                <!-- NB: we need to pass a pointer to the configuration element in the
                     input document. since we are calling apply-templates on an RTF,
                     recursive templates can no longer use the ancestor access to get
                     the input doc. instead, they can use the $configuration node
                     -->
                <xsl:apply-templates mode="StylePolicyRule" select="$theRule/StylePolicyRule/*">
                    <xsl:with-param name="configuration" select="$configuration"/>
                </xsl:apply-templates>

                <xsl:value-of select="concat('  exit', $eol)"/>
            </xsl:when>
            <!-- if global -->
            <xsl:otherwise>
                <!-- reference rule object -->
                <xsl:value-of select="concat('  match ', dpfunc:quoesc(Match), ' ', dpfunc:quoesc(Rule), $eol)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template mode="StylePolicy" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- TCPProxyService -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-object" match="TCPProxyService">
        <xsl:value-of select="concat($eol, 'tcpproxy ', dpfunc:quoesc(@name), ' ', dpfunc:quoesc(LocalAddress),
                              ' ', dpfunc:quoesc(LocalPort), ' ', dpfunc:quoesc(RemoteAddress), ' ', dpfunc:quoesc(RemotePort))"/>
        <xsl:if test="(Timeout != '')">
          <xsl:value-of select="concat(' ', dpfunc:quoesc(Timeout))"/>
        </xsl:if>
        <xsl:if test="(Priority != '')">
          <xsl:value-of select="concat(' ', dpfunc:quoesc(Priority))"/>
        </xsl:if>
        <xsl:if test="(UserSummary != '')">
          <xsl:value-of select="concat(' ', dpfunc:quoesc(UserSummary))"/>
        </xsl:if>
        <xsl:value-of select="$eol"/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- URLRefreshPolicy -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-object" match="URLRefreshPolicy">
        <xsl:value-of select="concat($eol, 'urlrefresh ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="URLRefreshPolicy"/>
        <xsl:value-of select="concat('exit', $eol)"/>
    </xsl:template>

    <xsl:template mode="URLRefreshPolicy" match="URLRefreshRule">
        <xsl:choose>
            <xsl:when test="URLRefreshPolicy='no-flush'">
                <xsl:value-of select="concat('  disable flush ', dpfunc:quoesc(URLMap), ' ', dpfunc:quoesc(URLRefreshInterval), $eol)"/>
            </xsl:when>
            <xsl:when test="URLRefreshPolicy='no-cache'">
                <xsl:value-of select="concat('  disable cache ', dpfunc:quoesc(URLMap), ' ', $eol)"/>
            </xsl:when>
            <xsl:when test="URLRefreshPolicy='protocol-specified'">
                <xsl:value-of select="concat('  protocol-specified ', dpfunc:quoesc(URLMap), ' ', dpfunc:quoesc(URLRefreshInterval), $eol)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat('  interval urlmap ', dpfunc:quoesc(URLMap), ' ', dpfunc:quoesc(URLRefreshInterval), $eol)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template mode="URLRefreshPolicy" match="*">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- ISAMReverseProxy -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-object" match="ISAMReverseProxy">
        <xsl:if test="Password and $delta-config=true()">
            <xsl:variable name="alias-object">
                <xsl:call-template name="do-mgmt-request">
                    <xsl:with-param name="session">
                        <xsl:value-of select="$sessionid"/>
                    </xsl:with-param>
                    <xsl:with-param name="request">
                        <request>
                          <operation type="get-config">
                            <request-class>PasswordAlias</request-class>
                            <request-name><xsl:value-of select="Password"/></request-name>
                          </operation>
                        </request>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:variable>
            <xsl:if test="not($alias-object/response/operation/configuration/PasswordAlias)">
                <xsl:value-of select="concat($eol, 'password-alias ',dpfunc:quoesc(Password), $eol)"/>
                <xsl:value-of select="concat('  password bogus', $eol)"/>
                <xsl:value-of select="concat('  admin-state disabled', $eol)"/>
                <xsl:value-of select="concat('  exit', $eol)"/>
                <xsl:variable name="domain">
                    <xsl:choose>
                        <xsl:when test="function-available('dpgui:get-user-session')">
                            <xsl:value-of select="dpgui:get-user-session($sessionid)/usersession/current-domain"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>default</xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:message dpe:type="mgmt" dpe:priority="notice" dpe:domain="{$domain}" dpe:id="{$DPLOG_WEBGUI_PASSWORD_ALIAS_CREATED}">
                    <dpe:with-param value="{Password}"/>
                </xsl:message>
            </xsl:if>
        </xsl:if>
        <xsl:value-of select="concat($eol, 'isam-reverseproxy ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="ISAMReverseProxy"/>
        <xsl:value-of select="concat('exit', $eol)"/>
    </xsl:template>

    <xsl:template mode="ISAMReverseProxy" match="*">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- XMLManager -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-object" match="XMLManager">
        <!-- if not marked as having been deleted -->
        <xsl:if test="not(@deleted='true')">
            <!-- if xmlmgr already existed, this will only re-enable it -->
            <xsl:value-of select="concat($eol, 'xmlmgr ',  dpfunc:quoesc(@name))"/>
            <xsl:if test="(SSLProxy != '')">
                <xsl:value-of select="concat(' ssl ',  dpfunc:quoesc(SSLProxy))"/>
            </xsl:if>
            <xsl:value-of select="$eol"/>

            <xsl:if test="($delta-config=true())">
                <!-- Remove associated URL refresh policy -->
                <xsl:value-of select="concat($eol, 'no xslrefresh ', dpfunc:quoesc(@name), $eol)"/>
                <!-- Remove all xpath function maps -->
                <xsl:value-of select="concat($eol, 'no xpath function map ', dpfunc:quoesc(@name), $eol)"/>
                <xsl:value-of select="concat($eol, 'no xslconfig ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:if>

            <!-- remaining properties are set outside -->
            <xsl:apply-templates mode="XMLManager"/>

            <xsl:value-of select="concat($eol,'xml parser limits ', dpfunc:quoesc(@name), $eol)"/>
            <xsl:if test="($delta-config=true())">
              <xsl:value-of select="concat('  reset', $eol)"/>
            </xsl:if>
            <xsl:apply-templates mode="ParserLimits"/>
            <xsl:value-of select="concat('exit', $eol)"/>

            <xsl:value-of select="concat($eol,'documentcache ', dpfunc:quoesc(@name), $eol)"/>
            <xsl:value-of select="concat(' no policy', $eol)"/>
            <xsl:apply-templates mode="DocumentCache"/>
            <xsl:value-of select="concat('exit', $eol)"/>

            <xsl:value-of select="concat('no xml validate ',
                                         dpfunc:quoesc(@name),
                                         ' *', $eol)"/>
            <xsl:apply-templates mode="SchemaValidation"
                                 select="SchemaValidation"/>

            <!-- new age XML Manager configuration -->
            <xsl:value-of select="concat($eol, 'xml-manager ', dpfunc:quoesc(@name), $eol)"/>
            <xsl:if test="($delta-config=true())">
                <xsl:value-of select="concat('  admin-state enabled',$eol)"/>
                <xsl:value-of select="concat('  no schedule-rule', $eol)"/>
                <xsl:value-of select="concat('  no loadbalancer-group', $eol)"/>
                <xsl:value-of select="concat('  no json-parser-settings', $eol)"/>
                <!-- Check to see if DFDL is licensed on this appliance -->
                <xsl:variable name="dfdl-is-licensed">
                    <xsl:call-template name="is-licensed">
                        <xsl:with-param name="featureToCheck" select="'DFDL'"/>
                    </xsl:call-template>
                </xsl:variable>
                <xsl:if test="($dfdl-is-licensed = 'true')">
                    <xsl:value-of select="concat('  no dfdl-settings-reference', $eol)"/>
                </xsl:if>
                <xsl:value-of select="concat('  no ldap-pool', $eol)"/>
            </xsl:if>
            <!-- if there's none specified, then don't remove the default -->
            <xsl:if test="not(UserAgent)">
                <xsl:value-of select="concat('  user-agent default', $eol)"/>
            </xsl:if>
            <xsl:apply-templates mode="XMLManagerCanonical"/>
            <xsl:value-of select="concat('exit', $eol)"/>

        </xsl:if>
    </xsl:template>

    <xsl:template mode="XMLManager" match="ExtensionFunctions">
        <xsl:value-of select="concat('xpath function map ', dpfunc:quoesc(../@name),
                              ' {', ExtensionFunctionNamespace, '}', ExtensionFunction,
                              ' {', LocalFunctionNamespace, '}', LocalFunction, $eol)"/>
    </xsl:template>

    <xsl:template mode="XMLManager" match="URLRefreshPolicy">
        <xsl:if test="text()!=''">
            <xsl:value-of select="concat('xslrefresh ', dpfunc:quoesc(../@name), ' ', dpfunc:quoesc(text()), $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="XMLManager" match="CompileOptionsPolicy">
        <xsl:if test="text()!=''">
            <xsl:value-of select="concat('xslconfig ', dpfunc:quoesc(../@name), ' ', dpfunc:quoesc(text()), $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="XMLManager" match="CacheSize">
        <xsl:if test="text()!=''">
            <xsl:value-of select="concat('xsl cache size ', dpfunc:quoesc(../@name), ' ', dpfunc:quoesc(text()), $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="XMLManager" match="Profiling">
        <xsl:if test="text()!=''">
          <xsl:value-of select="concat('xsl profile ', dpfunc:quoesc(../@name))"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="XMLManager" match="SupportTxWarn">
        <xsl:if test="(text()='off')">
            <xsl:value-of select="'no '"/>
        </xsl:if>
        <xsl:value-of select="concat('tx-warn ', dpfunc:quoesc(../@name), $eol)"/>
    </xsl:template>

    <xsl:template mode="XMLManager" match="SHA1Caching">
        <xsl:if test="(text()='off')">
            <xsl:value-of select="'no '"/>
        </xsl:if>
        <xsl:value-of select="concat('xsl checksummed cache ', ../@name, $eol)"/>
    </xsl:template>

    <xsl:template mode="XMLManager" match="Memoization">
        <xsl:if test="(text()='off')">
            <xsl:value-of select="'no '"/>
        </xsl:if>
        <xsl:value-of select="concat('memoization ', dpfunc:quoesc(../@name), $eol)"/>
    </xsl:template>

    <!-- 'xml parser limits' sub menu -->
    <xsl:template mode="XMLManager" match="ParserLimitsAttributeCount
                                           |ParserLimitsBytesScanned
                                           |ParserLimitsElementDepth
                                           |ParserLimitsMaxNodeSize
                                           |ParserLimitsForbidExternalReferences
                                           |ParserLimitsExternalReferences
                                           |ParserLimitsMaxPrefixes
                                           |ParserLimitsMaxNamespaces
                                           |ParserLimitsMaxLocalNames
                                           |ParserLimitsAttachmentByteCount
                                           |ParserLimitsAttachmentPackageByteCount"/>

    <xsl:template mode="ParserLimits" match="ParserLimitsAttributeCount
                                             |ParserLimitsBytesScanned
                                             |ParserLimitsElementDepth
                                             |ParserLimitsMaxNodeSize
                                             |ParserLimitsForbidExternalReferences
                                             |ParserLimitsExternalReferences
                                             |ParserLimitsMaxPrefixes
                                             |ParserLimitsMaxNamespaces
                                             |ParserLimitsMaxLocalNames
                                             |ParserLimitsAttachmentByteCount
                                             |ParserLimitsAttachmentPackageByteCount">
      <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
      </xsl:apply-templates>
    </xsl:template>

    <!-- 'documentcache' sub menu; can't use generic templates since 'reset' isn't emitted
         name and showNameInput are gui junk -->
    <xsl:template mode="XMLManager" match="DocCacheMaxDocs|DocMaxWrites|DocCacheSize|StaticDocumentCalls|DocCachePolicy|name|showNameInput" />

    <xsl:template mode="DocumentCache" match="DocCacheMaxDocs">
        <xsl:value-of select="concat(' maxdocs ', dpfunc:quoesc(.), $eol)"/>
    </xsl:template>
    <xsl:template mode="DocumentCache" match="DocCacheSize">
        <xsl:value-of select="concat(' size ', dpfunc:quoesc(.), $eol)"/>
    </xsl:template>
    <xsl:template mode="DocumentCache" match="DocMaxWrites">
        <xsl:value-of select="concat(' max-writes ', dpfunc:quoesc(.), $eol)"/>
    </xsl:template>

    <!-- this one uses an abnormal form; suppress default 'on' value  -->
    <xsl:template mode="DocumentCache" match="StaticDocumentCalls">
        <xsl:if test="($delta-config=true() or text()='off')">
            <xsl:value-of select="concat(' static-document-calls ', dpfunc:quoesc(text()), $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="DocumentCache" match="DocCachePolicy">
        <xsl:value-of select="concat(' policy ', dpfunc:quoesc(Match), ' ', dpfunc:quoesc(Priority), ' ')"/>
        <xsl:choose>
            <!-- type 'no-cache' expressed through 'nocache' in CLI -->
            <xsl:when test="(Type = 'no-cache')">
                <xsl:value-of select="concat('nocache', $eol)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:choose>
                    <!-- type 'protocol' expressed through either no TTL value or a 0 TTL value in CLI -->
                    <xsl:when test="(Type = 'protocol')">
                        <xsl:value-of select="concat('protocol', ' ', dpfunc:quoesc(XC10Grid), ' ')"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat(TTL, ' ', dpfunc:quoesc(XC10Grid), ' ')"/>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:choose>
                    <xsl:when test="(CacheBackendResponses = 'on')">
                        <xsl:value-of select="concat('on', ' ')"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('off', ' ')"/>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:choose>
                    <xsl:when test="(HTTPCacheValidation = 'on')">
                        <xsl:value-of select="concat('on', ' ')"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('off', ' ')"/>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:choose>
                    <xsl:when test="(ReturnExpired = 'on')">
                        <xsl:value-of select="concat('on', ' ')"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('off', ' ')"/>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:choose>
                    <xsl:when test="(RESTInvalidation = 'on')">
                        <xsl:value-of select="concat('on', ' ', 'off', $eol)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('off', ' ')"/>
                        <xsl:choose>
                            <xsl:when test="(CacheUnsafeResponse = 'on')">
                                <xsl:value-of select="concat('on', $eol)"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="concat('off', $eol)"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template mode="XMLManager" match="SchemaValidation"/>
    <xsl:template mode="SchemaValidation" match="SchemaValidation">
      <xsl:value-of select="concat('xml validate ', dpfunc:quoesc(../@name),
                                   ' ', dpfunc:quoesc(Matching))"/>
      <xsl:choose>
        <xsl:when test="ValidationMode = 'schema'">
          <xsl:value-of select="concat(' schema ', dpfunc:quoescne(SchemaURL))"/>
        </xsl:when>
        <xsl:when test="ValidationMode = 'dynamic-schema'">
          <xsl:value-of select="concat(' dynamic-schema ',
                                       dpfunc:quoesc(DynamicSchema))"/>
        </xsl:when>
        <xsl:when test="ValidationMode = 'attribute-rewrite'">
          <xsl:value-of select="concat(' attribute-rewrite ',
                                       dpfunc:quoesc(URLRewritePolicy))"/>
        </xsl:when>
        <xsl:when test="ValidationMode = 'schema-rewrite'">
          <xsl:value-of select="concat(' schema-rewrite ',
                                       dpfunc:quoesc(SchemaURL),
                                       ' ', dpfunc:quoesc(URLRewritePolicy))"/>
        </xsl:when>
        <xsl:when test="ValidationMode = 'default'">
            <!-- nothing to add to the command line here. -->
        </xsl:when>
      </xsl:choose>
      <xsl:value-of select="$eol"/>
    </xsl:template>

    <!-- suppress schedule-rule in XMLManager mode and handle in Canonical mode -->
    <xsl:template mode="XMLManager" match="ScheduledRule"/>
    <xsl:template mode="XMLManagerCanonical" match="ScheduledRule">
        <xsl:value-of select="concat('  schedule-rule ', dpfunc:quoesc(Rule), ' ', dpfunc:quoescne(Interval), $eol)"/>
    </xsl:template>

    <!-- suppress loadbalancer-group in XMLManager mode and handle in Canonical mode -->
    <xsl:template mode="XMLManager" match="VirtualServers"/>
    <xsl:template mode="XMLManagerCanonical" match="VirtualServers">
        <xsl:if test=". and (string(.) != '')">
            <xsl:value-of select="concat('  loadbalancer-group ', dpfunc:quoesc(.) , $eol)"/>
        </xsl:if>
    </xsl:template>

    <!-- New JSON property - json-parser-settings -->
    <!-- suppress json-parser-settings in XMLManager mode and handle in Canonical mode -->
    <xsl:template mode="XMLManager" match="JSONParserSettings"/>
    <xsl:template mode="XMLManagerCanonical" match="JSONParserSettings">
        <xsl:if test=". and (string(.) != '')">
            <xsl:value-of select="concat('  json-parser-settings ', dpfunc:quoesc(.) , $eol)"/>
        </xsl:if>
    </xsl:template>

    <!-- New DFDL property - dfdl-settings-reference -->
    <!-- suppress dfdl-settings-reference in XMLManager mode and handle in Canonical mode -->
    <xsl:template mode="XMLManager" match="DFDLSettingsReference"/>
    <xsl:template mode="XMLManagerCanonical" match="DFDLSettingsReference">
        <xsl:if test=". and (string(.) != '')">
            <!-- Check to see if DFDL is licensed on this appliance -->
            <xsl:variable name="dfdl-is-licensed">
                <xsl:call-template name="is-licensed">
                    <xsl:with-param name="featureToCheck" select="'DFDL'"/>
                </xsl:call-template>
            </xsl:variable>
            <xsl:if test="($dfdl-is-licensed = 'true')">
                <xsl:value-of select="concat('  dfdl-settings-reference ', dpfunc:quoesc(.) , $eol)"/>
            </xsl:if>
        </xsl:if>
    </xsl:template>

    <!-- New LDAP Connection Pool property - ldap-connection-pool -->
    <!-- suppress ldap-connection-pool in XMLManager mode and handle in Canonical mode -->
    <xsl:template mode="XMLManager" match="LDAPConnPool"/>
    <xsl:template mode="XMLManagerCanonical" match="LDAPConnPool">
        <xsl:if test=". and (string(.) != '')">
            <xsl:value-of select="concat('  ldap-pool ', dpfunc:quoesc(.) , $eol)"/>
        </xsl:if>
    </xsl:template>

    <!-- xmlmgr has no 'reset' - do manually or default can not be  restored -->
    <xsl:template mode="XMLManager" match="UserAgent"/>
    <xsl:template mode="XMLManagerCanonical" match="UserAgent">
      <xsl:if test=". and (string(.) != '')">
        <xsl:value-of select="concat('  user-agent ', dpfunc:quoesc(.) , $eol)"/>
      </xsl:if>
    </xsl:template>

    <!-- suppress admin-state and user-summary .. and do in Canonical mode -->
    <xsl:template mode="XMLManager" match="mAdminState|UserSummary"/>
    <xsl:template mode="XMLManagerCanonical" match="UserSummary|mAdminState">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- the troublesome global match that forces all the above suppressions -->
    <xsl:template mode="XMLManager" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- XSLProxyService -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-object" match="XSLProxyService">
        <!-- XSL proxy menu properties -->
        <xsl:value-of select="concat($eol, 'xslproxy ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="XSLProxyService"/>
        <xsl:value-of select="concat('exit', $eol )"/>
        <!-- HTTP proxy menu properties -->
        <xsl:call-template name="HTTPProxyServiceProperties">
            <xsl:with-param name="identifier" select="'xslproxy'"/>
        </xsl:call-template>
    </xsl:template>

    <!-- Dispatch from mode XSLProxyService or XMLFirewallService to the common leaf templates -->

    <xsl:template mode="XSLProxyService" match="LocalAddress
                                                |Type[text()='static-backend']
                                                |Type[text()='loopback-proxy']
                                                |Type[text()='dynamic-backend']
                                                |Type[text()='strict-proxy']
                                                |StylesheetParameters">
        <xsl:apply-templates mode="ProxyService" select="."/>
    </xsl:template>

    <xsl:template mode="XMLFirewallService" match="LocalAddress
                                                    |Type[text()='static-backend']
                                                    |Type[text()='loopback-proxy']
                                                    |Type[text()='dynamic-backend']
                                                    |Type[text()='strict-proxy']
                                                    |StylesheetParameters">
        <xsl:apply-templates mode="ProxyService" select="."/>
    </xsl:template>

    <xsl:template mode="XSLProxyService" match="*[starts-with(local-name(),'StylesheetParameter_name_')]">
        <xsl:call-template name="ProxyService_StylesheetParameter_name"/>
    </xsl:template>

    <xsl:template mode="XMLFirewallService" match="*[starts-with(local-name(),'StylesheetParameter_name_')]">
        <xsl:call-template name="ProxyService_StylesheetParameter_name"/>
    </xsl:template>

    <xsl:template mode="XSLProxyService" match="ACL">
        <xsl:apply-templates mode="ProxyService" select="."/>
    </xsl:template>

    <xsl:template mode="XMLFirewallService" match="ACL">
        <xsl:apply-templates mode="ProxyService" select="."/>
    </xsl:template>

    <xsl:template mode="XMLFirewallService" match="RewriteErrors">
        <!-- enable/disable -->
        <xsl:if test="(text()='on')">
                <xsl:value-of select="concat('  rewrite-errors', $eol)"/>
        </xsl:if>
        <xsl:if test="(text()='off')">
                <xsl:value-of select="concat('  no rewrite-errors', $eol)"/>
        </xsl:if>
    </xsl:template>
    
    <!-- Common code -->

    <xsl:template name="ProxyService_StylesheetParameter_name">
        <xsl:if test=". and (string(.) != '')">
            <xsl:variable name="param-pseudo-name" select="substring-after(local-name(), 'StylesheetParameter_name_')"/>
            <xsl:variable name="value-name" select="concat('StylesheetParameter_value_', $param-pseudo-name)"/>
            <xsl:value-of select="concat ('  parameter ', dpfunc:quoesc(.),
                                  ' ', dpfunc:quoesc(../*[local-name() = $value-name]), $eol)"/>
        </xsl:if>
    </xsl:template>

    <!-- default local-address + local-port properties -->
    <xsl:template mode="ProxyService" match="LocalAddress">
        <xsl:value-of select="concat('  local-address ', dpfunc:quoesc(text()), ' ', dpfunc:quoescne(../LocalPort), $eol)"/>
    </xsl:template>

    <!-- type 'static-backend' requires valid remoteAddr and remotePort -->
    <xsl:template mode="ProxyService" match="Type[text()='static-backend']">
        <xsl:value-of select="concat('  remote-address ', dpfunc:quoesc(../RemoteAddress), ' ', dpfunc:quoescne(../RemotePort), $eol)"/>
    </xsl:template>

    <!-- type 'loopback-proxy' is expressed with '%loopback%' as CLI remoteAddr -->
    <xsl:template mode="ProxyService" match="Type[text()='loopback-proxy']">
        <xsl:value-of select="concat('  remote-address %loopback%', $eol)"/>
    </xsl:template>

    <!-- type 'dynamic-backend' is expressed with '%dynamic%' as CLI remoteAddr -->
    <xsl:template mode="ProxyService" match="Type[text()='dynamic-backend']">
        <xsl:value-of select="concat('  remote-address %dynamic%', $eol)"/>
    </xsl:template>

    <!-- type 'strict-proxy' is expressed with '%proxy%' as CLI remoteAddr -->
    <xsl:template mode="ProxyService" match="Type[text()='strict-proxy']">
        <xsl:value-of select="concat('  remote-address %proxy%', $eol)"/>
    </xsl:template>

    <xsl:template mode="ProxyService" match="ACL">
      <xsl:if test="string(.)">
        <xsl:value-of select="concat('  acl ', dpfunc:quoesc(.), $eol)"/>
      </xsl:if>
    </xsl:template>

    <!-- default stylesheet parameter properties -->
    <xsl:template mode="ProxyService" match="StylesheetParameters">
        <xsl:value-of select="concat('  parameter ', dpfunc:quoesc(ParameterName), ' ', dpfunc:quoesc(ParameterValue), $eol)"/>
    </xsl:template>

    <!-- remaining XSLProxyService menu properties -->
    <xsl:template mode="XSLProxyService" match="XMLManager
                                                |StylePolicy
                                                |URLRewritePolicy
                                                |SSLProxy
                                                |CountMonitors
                                                |DurationMonitors
                                                |MonitorProcessingPolicy
                                                |DefaultParamNamespace
                                                |UserSummary
                                                |DebugMode
                                                |DebugHistory
                                                |DebuggerType
                                                |DebuggerURL
                                                |DebugTrigger
                                                |mAdminState
                                                |Priority
                                                |CredentialCharset
                                                |SSLConfigType
                                                |SSLServer
                                                |SSLSNIServer
                                                |SSLClient
                                                ">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
            <xsl:with-param name="Indent" select="'  '"/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- bug 9011: empty string is valid -->
    <xsl:template mode="XSLProxyService" match="QueryParamNamespace">
        <xsl:value-of select="concat('  query-param-namespace ',
                              dpfunc:quoesc(.), $eol)"/>
    </xsl:template>

    <xsl:template mode="XSLProxyService" match="*"/>

  <!-- ************************************************************ -->
  <!-- StylePolicyRule mode -->
  <!-- ************************************************************ -->

    <!-- suppress local rule objects, since they will be expressed otherwise,
         through the canonical object template -->
    <xsl:template mode="cli-object" match="StylePolicyRule[@local='true']"/>

    <xsl:template mode="cli-object" match="StylePolicyRule[not(@local='true')]">
        <xsl:value-of select="concat($eol, 'rule ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:value-of select="concat('  reset', $eol)"/>
        <xsl:apply-templates mode="StylePolicyRule">
            <xsl:with-param name="configuration" select=".."/>
        </xsl:apply-templates>
        <xsl:value-of select="concat('exit', $eol )"/>
    </xsl:template>

    <xsl:template mode="StylePolicyRule" match="Actions">
        <xsl:param name="configuration"/>

        <!--
             This is a reference property: we need to find the referenced object
             and inline it if (a) it is marked as local and (b) all it's properties
             can be expressed in the legacy one-line syntax.

             To find the referenced action, look in two places: (1) new configuration
             being submitted right now (2) existing config on box
             -->
        <xsl:variable name="actionName" select="."/>

        <!-- Find the referenced action. It may be in the incoming config or in the -->
        <!-- existing config -->
        <xsl:variable name="theAction">
            <xsl:choose>
                <xsl:when test="count($configuration/StylePolicyAction[@name=$actionName])">
                    <xsl:copy-of select="$configuration/StylePolicyAction[@name=$actionName]"/>
                </xsl:when>
                <xsl:when test="($delta-config)">
                    <xsl:copy-of select="$cli-existing//configuration/StylePolicyAction[@name=$actionName]"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>

        <!-- use a template to decide if the action can and should be expressed -->
        <!-- as a one-liner -->
        <xsl:variable name="IsLocal">
            <xsl:call-template name="IsActionLocal">
                <xsl:with-param name="action" select="$theAction/*"/>
            </xsl:call-template>
        </xsl:variable>

        <xsl:text>  </xsl:text>
        <xsl:choose>
            <xsl:when test="$IsLocal/local">
                <xsl:apply-templates mode="LocalStylePolicyAction" select="$theAction/*"/>
            </xsl:when>
            <xsl:otherwise>
                <!-- If the action's not local, you may not have access to it in Import.
                     But it turns out that all we need in that case is the name, which
                     we have. -->
                <xsl:value-of select="concat('  ', 'action', ' ', dpfunc:quoesc($actionName), $eol)"/>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>

  <!-- ************************************************************ -->
  <!-- StylePolicyAction mode -->
  <!-- ************************************************************ -->

    <!-- this template is applicable to both local and non-local actions,
         hence no suppression is needed -->
    <xsl:template mode="cli-object" match="StylePolicyAction">

        <xsl:variable name="IsLocal">
            <xsl:call-template name="IsActionLocal">
                <xsl:with-param name="action" select="."/>
            </xsl:call-template>
        </xsl:variable>

        <!-- only if it isn't local -->
        <xsl:if test="not($IsLocal/local)">
            <xsl:value-of select="concat($eol, 'action ', dpfunc:quoesc(@name), $eol)"/>
            <xsl:value-of select="concat('  reset', $eol)"/>
            <xsl:apply-templates mode="StylePolicyAction" select="*"/>
            <xsl:value-of select="concat('exit', $eol)"/>
        </xsl:if>

    </xsl:template>

    <!-- suppress log level for all non-log actions -->
    <xsl:template mode="StylePolicyAction" match="LogLevel[not(../Type='log')]"/>

    <!-- supress checkpoint event for all non-checkpoint actions -->
    <xsl:template mode="StylePolicyAction" match="CheckpointEvent[not(../Type='checkpoint')]"/>

    <!-- supress error-mode for all non-on-error actions -->
    <xsl:template mode="StylePolicyAction" match="ErrorMode[not(../Type='on-error')]"/>

    <!-- wish list: CanonicalProperty handles complex props (rtb: done.) -->
    <xsl:template mode="StylePolicyAction" match="StylesheetParameters">
        <xsl:value-of select="concat('  parameter ', dpfunc:quoesc(ParameterName), ' ', dpfunc:quoesc(ParameterValue), $eol)"/>
    </xsl:template>

    <xsl:template mode="StylePolicyAction" match="Type">
        <xsl:variable name="objName" select="name(..)"/>
        <xsl:variable name="pName" select="name()"/>
        <xsl:variable name="pNode"
            select="$config-objects-index/self::object[@name=$objName]/ancestor-or-self::*/properties/property[@name=$pName]"/>

        <xsl:value-of select="concat('  ', $pNode/cli-alias, ' ', ., $eol )"/>
    </xsl:template>

    <xsl:template mode="StylePolicyAction" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <xsl:template name="IsActionLocal">
        <xsl:param name="action"/>
        <xsl:choose>
          <xsl:when test="($action/@local='true')
                          and (count($action/StylesheetParameters)=0)
                          and ($action/OutputType = 'default')">
            <local/>
          </xsl:when>
          <xsl:otherwise></xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template mode="LocalStylePolicyAction" match="StylePolicyAction">
      <xsl:choose>
            <xsl:when test="(Type='xform' or Type='xformpi' or Type='xformbin')">
                <xsl:choose>
                    <xsl:when test="(DynamicStylesheet!='')">
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input),
                                              ' dynamic-stylesheet ', dpfunc:quoesc(DynamicStylesheet),
                                              ' ', dpfunc:quoesc(Output), $eol )"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input),
                                                     ' ', dpfunc:quoesc(Transform),
                                                     ' ', dpfunc:quoesc(Output))"/>
                        <xsl:if test="(Policy!='')">
                            <xsl:value-of select="concat(' ', dpfunc:quoesc(Policy))"/>
                        </xsl:if>
                        <xsl:value-of select="concat($eol)"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="(Type='validate')">
                <xsl:choose>
                    <xsl:when test="(DynamicSchema!='')">
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input),
                                                     ' dynamic-schema ', dpfunc:quoesc(DynamicSchema))"/>
                    </xsl:when>
                    <xsl:when test="(SchemaURL!='') and (Policy!='')">
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input),
                                                     ' schema-rewrite ',
                                                     dpfunc:quoesc(SchemaURL),
                                                     ' ', dpfunc:quoesc(Policy))"/>
                    </xsl:when>
                    <xsl:when test="(SchemaURL!='')">
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input),
                                                     ' schema ', dpfunc:quoesc(SchemaURL))"/>
                    </xsl:when>
                    <xsl:when test="(Policy!='')">
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input),
                                                     ' attribute-rewrite ', dpfunc:quoesc(Policy))"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input))"/>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:if test="(Output!='')">
                  <xsl:value-of select="concat(' ', dpfunc:quoesc(Output))"/>
                </xsl:if>
                <xsl:value-of select="concat($eol)"/>
            </xsl:when>

            <xsl:when test="Type='filter' or Type='route-action'">
                <xsl:choose>
                    <xsl:when test="(DynamicStylesheet!='')">
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input),
                                              ' dynamic-stylesheet ', dpfunc:quoesc(DynamicStylesheet) )"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input),
                                              ' ', dpfunc:quoesc(Transform) )"/>
                    </xsl:otherwise>
                </xsl:choose>
            <xsl:if test="(Output!='')">
                    <xsl:value-of select="concat(' ', dpfunc:quoesc(Output) )"/>
        </xsl:if>
                <xsl:value-of select="concat($eol)"/>
            </xsl:when>

            <xsl:when test="(Type='convert-http')">
                 <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input),
                                              ' ', dpfunc:quoesc(Output),
                                              ' ', InputConversion, $eol)"/>
            </xsl:when>

            <xsl:when test="(Type='rewrite')">
                 <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Policy), $eol)"/>
            </xsl:when>

            <xsl:when test="(Type='fetch')">
                 <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Destination),
                               ' ', dpfunc:quoesc(Output), $eol)"/>
            </xsl:when>

            <xsl:when test="(Type='extract')">
                 <xsl:value-of select="concat('  ', Type,
                 ' ', dpfunc:quoesc(Input),
                 ' ', dpfunc:quoesc(Output),
                 ' ', dpfunc:quoesc(XPath) )"/>

                 <xsl:if test="(Variable!='')">
                   <xsl:value-of select="concat(' ', dpfunc:quoesc(Variable))"/>
                 </xsl:if>
                 <xsl:value-of select="concat($eol)"/>
            </xsl:when>

            <xsl:when test="(Type='route-set')">
                 <xsl:value-of select="concat('  ', Type,
                 ' ', dpfunc:quoesc(Destination))"/>
                 <xsl:if test="(SSLCred!='')">
                    <xsl:value-of select="concat(' ', dpfunc:quoesc(SSLCred))"/>
                 </xsl:if>
                 <xsl:value-of select="concat($eol)"/>
            </xsl:when>

            <xsl:when test="(Type='strip-attachments')">
                 <xsl:value-of select="concat('  ', Type,
                 ' ', dpfunc:quoesc(Input))"/>
                 <xsl:if test="(AttachmentURI!='')">
                    <xsl:value-of select="concat(' ', dpfunc:quoesc(AttachmentURI))"/>
                 </xsl:if>
                 <xsl:value-of select="concat($eol)"/>
            </xsl:when>

            <xsl:when test="(Type='setvar')">
                 <xsl:value-of select="concat('  ', Type,
                                       ' ', dpfunc:quoesc(Input), ' ', dpfunc:quoesc(Variable),
                                       ' ', dpfunc:quoesc(Value), $eol)"/>
            </xsl:when>

            <xsl:when test="(Type='method-rewrite')">
                 <xsl:value-of select="concat('  ', Type,
                                       ' ', dpfunc:quoesc(MethodRewriteType), $eol)"/>
            </xsl:when>


            <xsl:when test="(Type='results')">
                <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input))"/>
            <xsl:if test="(Destination!='')">
                    <xsl:value-of select="concat(' ', dpfunc:quoesc(Destination))"/>
                    <xsl:value-of select="concat(' ', dpfunc:quoesc(MethodType))"/>
                    <xsl:if test="(Output!='')">
                        <xsl:value-of select="concat(' ', dpfunc:quoesc(Output))"/>
                    </xsl:if>
                </xsl:if>
                <xsl:value-of select="concat($eol)"/>
            </xsl:when>

            <xsl:when test="(Type='log')">
                <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input))"/>
            <xsl:if test="(Destination!='')">
                    <xsl:value-of select="concat(' ', dpfunc:quoesc(Destination))"/>
                    <xsl:value-of select="concat(' ', dpfunc:quoesc(MethodType2))"/>
                    <xsl:if test="(Output!='')">
                        <xsl:value-of select="concat(' ', dpfunc:quoesc(Output))"/>
                    </xsl:if>
                </xsl:if>
                <xsl:value-of select="concat($eol)"/>
            </xsl:when>

            <xsl:when test="(Type='results-async')">
              <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input))"/>
              <xsl:value-of select="concat(' ', dpfunc:quoesc(Destination))"/>
              <xsl:value-of select="$eol"/>
             </xsl:when>

             <xsl:when test="(Type='aaa')">
               <xsl:value-of select="concat( '  ', Type, ' ', dpfunc:quoesc(Input), ' ', dpfunc:quoesc(AAA), ' ', dpfunc:quoesc(Output), $eol )"/>
             </xsl:when>

             <xsl:when test="(Type='slm')">
               <xsl:value-of select="concat( '  ', Type, ' ', dpfunc:quoesc(Input), ' ', dpfunc:quoesc(SLMPolicy), ' ', dpfunc:quoesc(Output), $eol )"/>
             </xsl:when>

             <xsl:when test="(Type='sql')">
                <xsl:value-of select="concat( ' ', Type, ' ', dpfunc:quoesc(Input), ' ', dpfunc:quoesc(SQLDataSource), ' ', dpfunc:quoesc(SQLSourceType), ' ', dpfunc:quoesc(SQLText), ' ', $eol )"/>
             </xsl:when>

             <xsl:when test="(Type='call')">
               <xsl:value-of select="concat( '  ', Type, ' ', dpfunc:quoesc(Input), ' ', dpfunc:quoesc(Transform), ' ', dpfunc:quoesc(Output), $eol )"/>
             </xsl:when>

             <xsl:when test="(Type='checkpoint')">
               <xsl:value-of select="concat( '  ', Type, ' ', dpfunc:quoescne(CheckpointEvent), $eol )"/>
             </xsl:when>

             <xsl:when test="(Type='on-error')">
               <xsl:value-of select="concat( '  ', Type, ' ', dpfunc:quoescne(ErrorMode))"/>
               <xsl:if test="Rule!=''">
                 <xsl:value-of select="concat(' ', dpfunc:quoesc(Rule))"/>
               </xsl:if>
               <xsl:if test="ErrorInput!=''">
                 <xsl:value-of select="concat(' ', dpfunc:quoesc(ErrorInput))"/>
               </xsl:if>
               <xsl:if test="ErrorOutput!=''">
                 <xsl:value-of select="concat(' ', dpfunc:quoesc(ErrorOutput))"/>
               </xsl:if>
               <xsl:value-of select="$eol"/>
             </xsl:when>

             <xsl:otherwise>
               <xsl:value-of select="concat('unrecognized type ', Type)"/>
             </xsl:otherwise>

        </xsl:choose>
    </xsl:template>

    <xsl:template mode="StylePolicyRule" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- Matching -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-delete-object" match="Matching">
        <xsl:value-of select="concat('no matching ', dpfunc:quoesc(@name), $eol)"/>
    </xsl:template>

    <xsl:template mode="cli-object" match="Matching">
        <xsl:value-of select="concat($eol, 'matching ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="Matching"/>
        <xsl:value-of select="concat('exit', $eol )"/>
    </xsl:template>

    <xsl:template mode="Matching" match="MatchRules[Type='url']">
        <xsl:value-of select="concat('  urlmatch ', dpfunc:quoesc(Url), $eol)"/>
    </xsl:template>

    <xsl:template mode="Matching" match="MatchRules[Type='errorcode']">
      <xsl:value-of select="concat(' errorcode ', dpfunc:quoesc(ErrorCode), $eol)"/>
    </xsl:template>

    <xsl:template mode="Matching" match="MatchRules[Type='http']">
        <xsl:value-of select="concat('  httpmatch ', dpfunc:quoesc(HttpTag),
                                     ' ', dpfunc:quoesc(HttpValue), $eol)"/>
    </xsl:template>

    <xsl:template mode="Matching" match="MatchRules[Type='xpath']">
      <xsl:value-of select="concat(' xpathmatch ', dpfunc:quoesc(XPATHExpression), $eol)"/>
    </xsl:template>

    <xsl:template mode="Matching" match="MatchRules[Type='fullyqualifiedurl']">
        <xsl:value-of select="concat('  fullurlmatch ', dpfunc:quoesc(Url), $eol)"/>
    </xsl:template>

    <xsl:template mode="Matching" match="MatchRules[Type='host']">
        <xsl:value-of select="concat('  hostmatch ', dpfunc:quoesc(Url), $eol)"/>
    </xsl:template>

    <xsl:template mode="Matching" match="MatchRules[Type='method']">
        <xsl:value-of select="concat('  methodmatch ', dpfunc:quoesc(Method))"/>
        <xsl:if test="CustomMethod!=''">
            <xsl:value-of select="concat(dpfunc:quoesc(CustomMethod))"/>
        </xsl:if>
        <xsl:value-of select="concat($eol)"/>
    </xsl:template>

    <xsl:template mode="Matching" match="UserSummary|mAdminState|MatchWithPCRE|CombineWithOr">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <xsl:template mode="Matching" match="*"/>

    <!-- ************************************************************ -->
    <!-- Message Content Filters                                      -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-delete-object" match="MessageContentFilters">
        <xsl:value-of select="concat('no mcfilters ', dpfunc:quoesc(@name), $eol)"/>
    </xsl:template>

    <xsl:template mode="cli-object" match="MessageContentFilters">
        <xsl:value-of select="concat($eol, 'mcfilters ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="MessageContentFilters"/>
        <xsl:value-of select="concat('exit', $eol )"/>
    </xsl:template>

    <xsl:template mode="MessageContentFilters" match="Filters[Type='http']">
        <xsl:value-of select="concat('  http-mcfilter ', dpfunc:quoesc(FilterName), 
                                     ' ', dpfunc:quoesc(HttpName),
                                     ' ', dpfunc:quoesc(HttpValue), $eol)"/>
    </xsl:template>

    <xsl:template mode="MessageContentFilters" match="Filters[Type='xpath']">
      <xsl:value-of select="concat(' xpath-mcfilter ', dpfunc:quoesc(FilterName),
                                     ' ', dpfunc:quoesc(XPathExpression), 
                                     ' ', dpfunc:quoesc(XPathValue), $eol)"/>
    </xsl:template>

    <xsl:template mode="MessageContentFilters" match="FilterRefs">
      <xsl:value-of select="concat(' filter ', dpfunc:quoesc(text()) , $eol)"/>
    </xsl:template>

    <xsl:template mode="MessageContentFilters" match="UserSummary|mAdminState">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <xsl:template mode="MessageContentFilters" match="*"/>


    <!-- ************************************************************ -->
    <!-- ImportPackage -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-object" match="ImportPackage">
        <xsl:apply-templates mode="CanonicalObject" select="."/>
        <!-- if (creating config file or import-package came from outside
             the appliance) and admin state is enabled and the
	     import-package should be automaticaly executed, -->
        <!-- add 'import-execute objname' directive          -->
	<!-- EXTERNAL-CONFIG check added to correct similar bug to 29748,
             after delta-config set to true for bug 29960    -->
        <xsl:if test="((($delta-config=false()) or boolean($EXTERNAL-CONFIG))
                        and (mAdminState='enabled') and (OnStartup='on'))">
            <xsl:value-of select="concat($eol,'import-execute ', dpfunc:quoesc(@name),$eol)"/>
        </xsl:if>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- IncludeConfig -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-object" match="IncludeConfig">
        <xsl:apply-templates mode="CanonicalObject" select="."/>
        <!-- if creating config file and admin state is enabled -->
        <xsl:if test="(($delta-config=false()) and (mAdminState='enabled') and (OnStartup='on'))">
            <xsl:choose>
                <xsl:when test="InterfaceDetection='on'">
                    <!-- add 'exec objname' directive -->
                    <xsl:value-of select="concat($eol,'exec ', dpfunc:quoesc(@name),$eol)"/>
                </xsl:when>
                <xsl:otherwise>
                    <!-- add 'exec url' directive -->
                    <xsl:value-of select="concat($eol,'exec ', dpfunc:quoesc(URL),$eol)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- ShellAlias -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-object" match="ShellAlias">
        <xsl:value-of select="concat($eol, 'alias ', dpfunc:quoesc(@name),
                                     ' ', dpfunc:quoesc(normalize-space(command)), $eol)"/>
    </xsl:template>

    <!-- XSLCoprocService -->
    <xsl:template mode="cli-object" match="XSLCoprocService">
        <xsl:call-template name="available-open">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>

        <xsl:value-of select="concat($eol, 'xslcoproc ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="XSLCoprocService"/>
        <xsl:value-of select="concat('exit', $eol )"/>
        <xsl:call-template name="available-close">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>

    </xsl:template>

    <!-- local-address + local-port properties -->
    <xsl:template mode="XSLCoprocService" match="LocalAddress">
        <xsl:value-of select="concat('  local-address ', dpfunc:quoesc(text()), ' ', ../LocalPort, $eol)"/>
    </xsl:template>

    <xsl:template mode="XSLCoprocService" match="LocalPort"/>

    <!-- default-param-namespace -->
    <xsl:template mode="XSLCoprocService" match="DefaultParamNamespace">
        <xsl:value-of select="concat('  default-param-namespace ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <!-- remaining XSLCoprocService menu properties -->
    <xsl:template mode="XSLCoprocService" match="*">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
            <xsl:with-param name="Indent" select="'  '"/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- URLRewritePolicy -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-object" match="URLRewritePolicy">
        <xsl:value-of select="concat($eol, 'urlrewrite ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="URLRewritePolicy"/>
        <xsl:value-of select="concat('exit', $eol)"/>
    </xsl:template>


    <xsl:template mode="URLRewritePolicy" match="URLRewriteRule">
        <xsl:variable name="input-replace">
            <xsl:apply-templates select="InputReplaceRegexp" mode="NullableValue"/>
        </xsl:variable>
        <xsl:variable name="style-replace">
            <xsl:apply-templates select="StyleReplaceRegexp" mode="NullableValue"/>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="Type='content-type'">
                <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(MatchRegexp),
                                             ' ', $input-replace, ' ', NormalizeURL, $eol )"/>
            </xsl:when>
            <xsl:when test="Type='post-body'">
                <xsl:value-of select="concat('  ', Type, ' ', $quote, $quote, ' ', dpfunc:quoesc(MatchRegexp),
                                             ' ', $input-replace, ' ', $style-replace,
                                             ' ', InputUnescape, ' ', StylesheetUnescape, ' ', NormalizeURL, $eol )"/>
            </xsl:when>
            <xsl:when test="Type='header-rewrite'">
                <xsl:value-of select="concat('  ', Type, ' ', Header, ' ', dpfunc:quoesc(MatchRegexp),
                                             ' ', $input-replace, ' ', NormalizeURL, $eol )"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(MatchRegexp),
                                             ' ', $input-replace, ' ', $style-replace,
                                             ' ', InputUnescape, ' ', StylesheetUnescape, ' ', NormalizeURL, $eol )"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template mode="URLRewritePolicy" match="mAdminState">
      <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <xsl:template mode="URLRewritePolicy" match="Direction">
      <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <xsl:template mode="URLRewritePolicy" match="*"/>

    <!-- ************************************************************ -->
    <!-- SSLProxyProfile -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-object" match="SSLProxyProfile">
        <xsl:value-of select="concat($eol, 'sslproxy ', dpfunc:quoesc(@name), ' ', dpfunc:quoesc(Direction))"/>

        <xsl:if test="Direction = 'reverse' or Direction = 'two-way'">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(ReverseCryptoProfile))"/>
        </xsl:if>
        <xsl:if test="Direction = 'forward' or Direction = 'two-way'">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(ForwardCryptoProfile))"/>
        </xsl:if>

        <xsl:apply-templates mode="SSLProxyProfile"/>
        <xsl:value-of select="concat($eol)"/>
    </xsl:template>

    <!-- These are handled in main template for SSLProxyProfile -->
    <xsl:template mode="SSLProxyProfile" match="ForwardCryptoProfile"/>
    <xsl:template mode="SSLProxyProfile" match="ReverseCryptoProfile"/>
    <xsl:template mode="SSLProxyProfile" match="Direction"/>

    <xsl:template mode="SSLProxyProfile" match="ServerCaching">
        <xsl:if test="../Direction = 'reverse' or ../Direction = 'two-way'">
            <xsl:choose>
                <!-- ServerCaching is just a flag indicating that server
                     caching is on or off, if off then sess-timeout must
                     be 0 -->
                <xsl:when test=". = 'off'">
                    <xsl:value-of select="concat(' sess-timeout 0')"/>
                </xsl:when>

                <xsl:otherwise>
                    <xsl:value-of select="concat(' sess-timeout ', dpfunc:quoesc(../SessionTimeout), ' cache-size ', dpfunc:quoesc(../CacheSize))"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="SSLProxyProfile" match="mAdminState">
      <xsl:if test="../mAdminState='disabled'">
        <xsl:value-of select="concat(' admin-state ',dpfunc:quoesc(.))"/>
      </xsl:if>
    </xsl:template>

    <!-- Eat SessionTimeout and CacheSize because they're handled in the
         template for ServerCaching -->
    <xsl:template mode="SSLProxyProfile" match="SessionTimeout|CacheSize"/>

    <xsl:template mode="SSLProxyProfile" match="ClientCache">
        <xsl:if test="(../Direction = 'forward' or ../Direction = 'two-way') and (../ClientCache = 'on' or ../ClientCache = 'off')">
            <xsl:value-of select="concat(' client-cache ', dpfunc:quoesc(text()))"/>
        </xsl:if>
    </xsl:template>
    <xsl:template mode="SSLProxyProfile" match="ClientSessionTimeout">
        <xsl:if test="(../Direction = 'forward' or ../Direction = 'two-way') and ../ClientCache = 'on'">
            <xsl:value-of select="concat(' client-sess-timeout ', dpfunc:quoesc(text()))"/>
        </xsl:if>
    </xsl:template>
    <xsl:template mode="SSLProxyProfile" match="ClientCacheSize">
        <xsl:if test="(../Direction = 'forward' or ../Direction = 'two-way') and ../ClientCache = 'on'">
            <xsl:value-of select="concat(' client-cache-size ', dpfunc:quoesc(text()))"/>
        </xsl:if>
    </xsl:template>

    <!--
         These parameters were added to this command *much* later than the rest
         of the parameters, so it is very important not to serialize them at all
         unless they have the non-default value (so as to be downgrade
         compatible if at all possible).
      -->
    <xsl:template mode="SSLProxyProfile"
                  match="ClientAuthOptional|ClientAuthAlwaysRequest">
        <xsl:if test="(../Direction = 'reverse' or ../Direction = 'two-way') and text() = 'on'">
            <!--
                 This should really just use cli-alias (instead of xsl:choose),
                 but it isn't clear how to do so.
            -->
            <xsl:choose>
                <xsl:when test="self::ClientAuthOptional">
                    <xsl:value-of select="' client-auth-optional on'"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="' client-auth-always-request on'"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
    </xsl:template>
    <xsl:template mode="SSLProxyProfile"
                  match="PermitInsecureServers">
        <xsl:if test="(../Direction = 'forward' or ../Direction = 'two-way') and text() = 'on'">
            <xsl:value-of select="' permit-insecure-servers on'"/>
        </xsl:if>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- XMLFirewallService -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-object" match="XMLFirewallService">
        <xsl:call-template name="available-open">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>

        <xsl:variable name="importFromWebsphere" select="/request/args/importedFromWebsphere"/>
        <xsl:choose>
            <xsl:when test="$importFromWebsphere='true'">
                <xsl:call-template name="XMLFirewallServiceWebsphere">
                    <xsl:with-param name="args" select="."/>
                </xsl:call-template>
            </xsl:when>
        </xsl:choose>

        <!-- XML Firewall menu properties -->
        <xsl:value-of select="concat($eol, 'xmlfirewall ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="XMLFirewallService"/>
        <xsl:value-of select="concat('exit', $eol )"/>
        <!-- HTTP proxy menu properties -->
        <xsl:call-template name="HTTPProxyServiceProperties">
            <xsl:with-param name="identifier" select="'xmlfirewall'"/>
        </xsl:call-template>
        <xsl:call-template name="available-close">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>
    </xsl:template>

    <!-- bug 9011: empty string is valid -->
    <xsl:template mode="XMLFirewallService" match="QueryParamNamespace">
        <xsl:value-of select="concat('  query-param-namespace ',
                              dpfunc:quoesc(.), $eol)"/>
    </xsl:template>

    <!-- remaining XMLFirewallService menu properties -->
    <xsl:template mode="XMLFirewallService" match="XMLManager
                                                    |StylePolicy
                                                    |URLRewritePolicy
                                                    |SSLProxy
                                                    |MaxMessageSize
                                                    |RequestType
                                                    |ResponseType
                                                    |FWCred
                                                    |CountMonitors
                                                    |DurationMonitors
                                                    |ServiceMonitors
                                                    |MonitorProcessingPolicy
                                                    |DefaultParamNamespace
                                                    |RequestAttachments
                                                    |ResponseAttachments
                                                    |RootPartNotFirstAction
                                                    |MIMEHeaders
                                                    |mAdminState
                                                    |UserSummary
                                                    |SOAPSchemaURL
                                                    |DebugMode
                                                    |DebugHistory
                                                    |DebuggerType
                                                    |DebuggerURL
                                                    |DebugTrigger
                                                    |FirewallParserLimits
                                                    |WSDLResponsePolicy
                                                    |WSDLFileLocation
                                                    |ParserLimitsBytesScanned
                                                    |ParserLimitsElementDepth
                                                    |ParserLimitsAttributeCount
                                                    |ParserLimitsMaxNodeSize
                                                    |ParserLimitsExternalReferences
                                                    |ParserLimitsForbidExternalReferences
                                                    |ParserLimitsMaxPrefixes
                                                    |ParserLimitsMaxNamespaces
                                                    |ParserLimitsMaxLocalNames
                                                    |ParserLimitsAttachmentByteCount
                                                    |ParserLimitsAttachmentPackageByteCount
                                                    |FrontAttachmentFormat
                                                    |BackAttachmentFormat
                                                    |Priority
                                                    |ForcePolicyExec
                                                    |DelayErrors
                                                    |DelayErrorsDuration
                                                    |CredentialCharset
                                                    |SSLConfigType
                                                    |SSLServer
                                                    |SSLSNIServer
                                                    |SSLClient
                                                    ">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
            <xsl:with-param name="Indent" select="'  '"/>
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template mode="XMLFirewallService" match="*"/>

    <!-- ***************************************************** -->
    <!--  AAAPolicy                                       -->
    <!-- ***************************************************** -->

    <xsl:template mode="cli-object" match="AAAPolicy">
        <xsl:call-template name="available-open">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>
      <xsl:value-of select="concat($eol, 'aaapolicy ', dpfunc:quoesc(@name), $eol)"/>
      <xsl:if test="($delta-config=true())">
          <xsl:value-of select="concat('  reset', $eol)"/>
      </xsl:if>

      <xsl:apply-templates mode="AAAPolicy"/>
      <xsl:value-of select="concat('exit', $eol)"/>
        <xsl:call-template name="available-close">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="AAAPolicy" match="Authenticate|Authorize|MapCredentials|MapResource|ExtractIdentity|PostProcess|ExtractResource">
        <xsl:variable name="current" select="." />
        <xsl:variable name="schema-prop-node" select="$config-objects-index/self::object[@name = 'AAAPolicy']/properties/property[@name = local-name($current)]" />

        <!-- cli command from drMgmt -->
        <xsl:value-of select='concat(" ",normalize-space($schema-prop-node/cli-alias)," ")'/>


        <!-- these four groups, the second command arg represents one of two properties -->
        <xsl:if test="boolean(
                               local-name() = 'Authenticate' or
                               local-name() = 'Authorize' or
                               local-name() = 'MapCredentials' or
                               local-name() = 'MapResource'
                             )">
            <xsl:variable name="method" select="AUMethod|MCMethod|MRMethod|AZMethod" />

            <!-- include the first argument for this set is "method" -->
            <xsl:value-of select='concat($method, " ")' />

            <!-- the second argument for this set is the custom url, map url, xpath expression, or "" -->
      <xsl:choose>
        <xsl:when test="$method = 'custom'">
                    <xsl:value-of select="dpfunc:quoesc( AUCustomURL|MCCustomURL|MRCustomURL|AZCustomURL )" />
        </xsl:when>
        <xsl:when test="$method = 'xmlfile'">
                    <xsl:value-of select="dpfunc:quoesc( AUMapURL|MCMapURL|MRMapURL|AZMapURL )" />
        </xsl:when>
        <xsl:when test="$method = 'xpath'">
                    <xsl:value-of select="dpfunc:quoesc( MCMapXPath|MRMapXPath )" />
        </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="dpfunc:quoesc('')" />
                </xsl:otherwise>
      </xsl:choose>
        </xsl:if>

        <!-- arguments are supplied in the same order as listed in drMgmt.
             For AU, MC, MR, and AZ, skip the method and url properties since they are set above
          -->
        <xsl:for-each select="$type-index/self::type[@name = $schema-prop-node/@type]/properties/property[
                              not( regexp:test( @name, '^(AU|MC|MR|AZ)(Method|CustomURL|MapURL)$' ) ) ]">
            <xsl:variable name="arg-node" select="$current/*[local-name() = current()/@name]" />

          <xsl:choose>
                <xsl:when test="string($type-index/self::type[@name = current()/@type]/@base) = 'bitmap'">
                    <xsl:value-of select='concat(" ", dpfunc:quoesc(dpfunc:bitmap-to-string($arg-node)))' />
            </xsl:when>
            <xsl:otherwise>
                    <xsl:value-of select='concat(" ", dpfunc:quoesc($arg-node))'/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>

      <xsl:value-of select="$eol"/>
    </xsl:template>

    <!-- this -1 priority template will match everything else not specified by other AAAPolicy templates. -->
    <xsl:template mode="AAAPolicy" match="*" priority="-1">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <xsl:template mode="AAAPolicy" match="NamespaceMapping">
      <xsl:value-of select="concat('  namespace-mapping ', dpfunc:quoesc(Prefix), ' ', dpfunc:quoesc(URI), $eol)"/>
    </xsl:template>

    <xsl:template mode="AAAPolicy" match="SAMLAttribute">
      <xsl:value-of select="concat('  saml-attribute ', dpfunc:quoesc(URI),
                                   ' ', dpfunc:quoesc(LocalName),
                                   ' ', dpfunc:quoesc(Value), $eol)"/>
    </xsl:template>

    <xsl:template mode="AAAPolicy" match="LTPAAttributes">
        <xsl:value-of select="concat(' ltpa-attribute ',
                              dpfunc:quoesc(LTPAUserAttributeName), ' ',
                              dpfunc:quoesc(LTPAUserAttributeType), ' ',
                              dpfunc:quoesc(LTPAUserAttributeStaticValue), ' ',
                              dpfunc:quoesc(LTPAUserAttributeXPathValue),
                              $eol)"/>
    </xsl:template>

    <xsl:template mode="AAAPolicy" match="TransactionPriority">
        <xsl:value-of select="concat(' transaction-priority ',
                              dpfunc:quoesc(Credential), ' ',
                              dpfunc:quoesc(Priority), ' ',
                              dpfunc:quoesc(Authorization), ' ',
                              $eol)"/>
    </xsl:template>


    <!-- ************************************************************ -->
    <!-- XMLFirewallServiceWebsphere -->
    <!-- ************************************************************ -->

    <xsl:template name="XMLFirewallServiceWebsphere">
        <xsl:param name="args"/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- Crypto -->
    <!-- ************************************************************ -->

    <!-- Used by crypto templates to wrap "crypto" .. "exit" around crypto commands -->
    <xsl:template name="CryptoWrapper">
        <xsl:param name="cmdline"/>
        <xsl:if test="$cmdline != ''">
            <xsl:value-of select="concat($eol, 'crypto', $eol, '  ', $cmdline, $eol, 'exit', $eol)"/>
        </xsl:if>
    </xsl:template>

     <xsl:template name="CryptoPassword">
        <xsl:param name="alias"/>
        <xsl:param name="password"/>
        <xsl:param name="aliasToggle"/>

        <xsl:choose>
            <xsl:when test="(not($aliasToggle) or ($alias))">
                <xsl:if test="(string($password) != '')">
                    <xsl:value-of select="concat(' password ', dpfunc:quoesc($password))"/>  
                </xsl:if>
                <xsl:if test="(string($alias) != '')">
                    <xsl:value-of select="concat(' password-alias ', dpfunc:quoesc($alias))"/>  
                </xsl:if>
            </xsl:when>
            <xsl:otherwise>
                <xsl:if test="(string($password) != '')">
                    <xsl:choose>
                        <xsl:when test="($aliasToggle='on')">
                            <xsl:value-of select="concat(' password-alias ', dpfunc:quoesc($password))"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="concat(' password ', dpfunc:quoesc($password))"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:if>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- CryptoKey -->
    <xsl:template mode="cli-delete-object" match="CryptoKey">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no key ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="CryptoKey">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
            <xsl:value-of select="concat('key ', dpfunc:quoesc(@name), ' ', dpfunc:quoesc(Filename))"/>

            <xsl:call-template name="CryptoPassword">
                <xsl:with-param name="alias" select="Alias"/>
                <xsl:with-param name ="password" select="Password"/>
                <xsl:with-param name ="aliasToggle" select="PasswordAlias"/>
            </xsl:call-template>

            <xsl:if test="string(mAdminState) = 'disabled'">
                <xsl:value-of select="concat(' admin-state ', dpfunc:quoesc(mAdminState))"/>
            </xsl:if>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <!-- CryptoSSKey -->
    <xsl:template mode="cli-delete-object" match="CryptoSSKey">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no sskey ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="CryptoSSKey">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('sskey ', dpfunc:quoesc(@name), ' ', dpfunc:quoesc(Filename))"/>
                
                <xsl:call-template name="CryptoPassword">
                    <xsl:with-param name="alias" select="Alias"/>
                    <xsl:with-param name ="password" select="Password"/>
                    <xsl:with-param name ="aliasToggle" select="PasswordAlias"/>
                </xsl:call-template>

                <xsl:if test="(string(mAdminState) = 'disabled')">
                  <xsl:value-of select="concat(' admin-state ',dpfunc:quoesc(mAdminState))"/>
                </xsl:if>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <!-- CryptoCertificate -->
    <xsl:template mode="cli-delete-object" match="CryptoCertificate">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no certificate ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="CryptoCertificate">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('certificate ', dpfunc:quoesc(@name), ' ', dpfunc:quoesc(Filename))"/>
                
                <xsl:call-template name="CryptoPassword">
                    <xsl:with-param name="alias" select="Alias"/>
                    <xsl:with-param name ="password" select="Password"/>
                    <xsl:with-param name ="aliasToggle" select="PasswordAlias"/>
               </xsl:call-template>

                <xsl:if test="(string(mAdminState) = 'disabled')">
                  <xsl:value-of select="concat(' admin-state ',dpfunc:quoesc(mAdminState))"/>
                </xsl:if>
                <xsl:if test="string(IgnoreExpiration) = 'on'">
                  <xsl:value-of select="' ignore-expiration'"/>
                </xsl:if>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <!-- CryptoIdentCred -->
    <xsl:template mode="cli-delete-object" match="CryptoIdentCred">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no idcred ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="CryptoIdentCred">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('idcred ', dpfunc:quoesc(@name),
                                             ' ', dpfunc:quoesc(Key),
                                             ' ', dpfunc:quoesc(Certificate))"/>
                <xsl:if test="(CA) and not(string(CA)='')">
                    <xsl:apply-templates mode="CryptoIdentCred"/>
                </xsl:if>
                <xsl:if test="(string(mAdminState) = 'disabled')">
                  <xsl:value-of select="concat(' admin-state ',dpfunc:quoesc(mAdminState))"/>
                </xsl:if>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="CryptoIdentCred" match="CA">
        <xsl:value-of select="concat(' ca ', dpfunc:quoesc(text()))"/>
    </xsl:template>

    <!-- CryptoValCred -->
    <xsl:template mode="cli-delete-object" match="CryptoValCred">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no valcred ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="CryptoValCred">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('valcred ', dpfunc:quoesc(@name), $eol)"/>
                <xsl:if test="($delta-config=true())">
                    <xsl:value-of select="concat('  reset', $eol)"/>
                </xsl:if>
                <xsl:apply-templates mode="CryptoValCred"/>
                <xsl:value-of select="concat('  exit')"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="Certificate">
        <xsl:if test="text()">
            <xsl:value-of select="concat('    certificate ', dpfunc:quoesc(text()), $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="mAdminState">
      <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="CertValidationMode">
        <xsl:value-of select="concat('    cert-validation-mode ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="UseCRL">
        <xsl:value-of select="concat('    use-crl ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="RequireCRL">
        <xsl:value-of select="concat('    require-crl ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="CRLDPHandling">
        <xsl:value-of select="concat('    crldp ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="InitialPolicySet">
        <xsl:value-of select="concat('    initial-policy-set ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="ExplicitPolicy">
        <xsl:value-of select="concat('    explicit-policy ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="CheckDates">
        <xsl:value-of select="concat('    check-dates ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template name="CreateValidObjectName">
        <xsl:param name="input-name"/>
        <!-- translate characters which are illegal in named object names into
             something legal; note that ':' is deleted and not translated -->
        <xsl:value-of select="translate($input-name, '.,;#/\():', '--------')"/>
    </xsl:template>

    <!-- CryptoProfile -->
    <xsl:template mode="cli-delete-object" match="CryptoProfile">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no profile ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="CryptoProfile">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:choose>
                    <xsl:when test="string(IdentCredential) = ''">
                        <xsl:value-of select="concat('profile ', dpfunc:quoesc(@name),
                                              ' ', $quote, '%none%', $quote)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('profile ', dpfunc:quoesc(@name),
                                              ' ', dpfunc:quoesc(IdentCredential))"/>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:if test="SSLOptions/*">
                    <xsl:value-of select="concat(' option-string ')"/>
                    <xsl:for-each select="SSLOptions/(custom|*[.='on'])">
                        <xsl:variable name="optionName" select="local-name()"/>
                        <xsl:choose>
                            <xsl:when test="$optionName='custom'">
                                <xsl:value-of select="."/>
                                <xsl:if test="position() != last()">
                                    <xsl:value-of select="'+'"/>
                                </xsl:if>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="$optionName"/>
                                <xsl:if test="position() != last()">
                                    <xsl:value-of select="'+'"/>
                                </xsl:if>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                </xsl:if>
                <xsl:apply-templates mode="CryptoProfile"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="CryptoProfile" match="IdentCredential|SSLOptions"/>

    <!-- default inline crypto profile properties -->
    <xsl:template mode="CryptoProfile" match="*">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
            <xsl:with-param name="Inline" select="''"/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- CryptoEngine : Don't generate engine commands, the crypto
         engine is autodetected right now, and there is no 'no engine'
         command -->
    <xsl:template mode="cli-delete-object" match="CryptoEngine"/>
    <xsl:template mode="cli-object" match="CryptoEngine"/>

    <!-- CryptoFWCred -->
    <xsl:template mode="cli-delete-object" match="CryptoFWCred">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no fwcred ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="CryptoFWCred">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('fwcred ', dpfunc:quoesc(@name), $eol)"/>
                <xsl:if test="($delta-config=true())">
                    <xsl:value-of select="concat('    reset', $eol)"/>
                </xsl:if>
                <xsl:apply-templates mode="CryptoFWCred"/>
                <xsl:value-of select="concat('  exit')"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="CryptoFWCred" match="PrivateKey">
        <xsl:value-of select="concat('    key ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoFWCred" match="SharedSecretKey">
        <xsl:value-of select="concat('    sskey ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoFWCred" match="Certificate">
        <xsl:value-of select="concat('    certificate ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoFWCred" match="mAdminState">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- CertMonitor -->
    <!-- there is no 'no cert-monitor' command -->
    <xsl:template mode="cli-delete-object" match="CertMonitor"/>

    <xsl:template mode="cli-object" match="CertMonitor">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:apply-templates mode="CanonicalObject" select="."/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <!-- Kerberos KDC -->
    <xsl:template mode="cli-object" match="CryptoKerberosKDC">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:apply-templates mode="CanonicalObject" select="."/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-delete-object" match="CryptoKerberosKDC">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
            <xsl:value-of select="concat('no kerberos-kdc ', dpfunc:quoesc(@name), $eol)"/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <!-- Kerberos Keytab -->
    <xsl:template mode="cli-object" match="CryptoKerberosKeytab">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:apply-templates mode="CanonicalObject" select="."/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-delete-object" match="CryptoKerberosKeytab">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:value-of select="concat('no kerberos-keytab ', dpfunc:quoesc(@name), $eol)"/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>
    
    <!-- Cookie Attribute Policy -->
    <xsl:template mode="cli-object" match="CookieAttributePolicy">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:apply-templates mode="CanonicalObject" select="."/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-delete-object" match="CookieAttributePolicy">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:value-of select="concat('no cookie-attribute-policy ', dpfunc:quoesc(@name), $eol)"/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <!-- JWS/JWE association object -->
    <!-- JOSSignatureIdentifier -->
    <xsl:template mode="cli-delete-object" match="JOSESignatureIdentifier">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no jose-signature-identifier ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="JOSESignatureIdentifier">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:apply-templates mode="CanonicalObject" select="."/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <!-- JOSERecipientIdentifier -->
    <xsl:template mode="cli-delete-object" match="JOSERecipientIdentifier">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no jose-recipient-identifier ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="JOSERecipientIdentifier">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:apply-templates mode="CanonicalObject" select="."/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <!-- JWSSignature -->
    <xsl:template mode="cli-delete-object" match="JWSSignature">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no jws-signature ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="JWSSignature">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:apply-templates mode="CanonicalObject" select="."/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <!-- JWEHeader -->
    <xsl:template mode="cli-delete-object" match="JWEHeader">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no jwe-header ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="JWEHeader">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:apply-templates mode="CanonicalObject" select="."/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <!-- JWERecipient -->
    <xsl:template mode="cli-delete-object" match="JWERecipient">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no jwe-recipient ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="JWERecipient">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:apply-templates mode="CanonicalObject" select="."/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <!-- SSL Client Profile -->
    <xsl:template mode="cli-object" match="SSLClientProfile">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:apply-templates mode="CanonicalObject" select="."/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-delete-object" match="SSLClientProfile">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:value-of select="concat('no ssl-client ', dpfunc:quoesc(@name), $eol)"/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <!-- SSL Server Profile -->
    <xsl:template mode="cli-object" match="SSLServerProfile">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:apply-templates mode="CanonicalObject" select="."/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-delete-object" match="SSLServerProfile">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:value-of select="concat('no ssl-server ', dpfunc:quoesc(@name), $eol)"/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <!-- SSL SNI Mapping -->
    <xsl:template mode="cli-object" match="SSLSNIMapping">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:apply-templates mode="CanonicalObject" select="."/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-delete-object" match="SSLSNIMapping">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:value-of select="concat('no ssl-sni-mapping ', dpfunc:quoesc(@name), $eol)"/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <!-- SSL SNI Profile -->
    <xsl:template mode="cli-object" match="SSLSNIServerProfile">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:apply-templates mode="CanonicalObject" select="."/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-delete-object" match="SSLSNIServerProfile">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:value-of select="concat('no ssl-sni-server ', dpfunc:quoesc(@name), $eol)"/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <!-- JWT Validtor -->
    <xsl:template mode="cli-object" match="AAAJWTValidator">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:apply-templates mode="CanonicalObject" select="."/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-delete-object" match="AAAJWTValidator">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:value-of select="concat('no jwt-validator ', dpfunc:quoesc(@name), $eol)"/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

        <!-- JWT Generator -->
    <xsl:template mode="cli-object" match="AAAJWTGenerator">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:apply-templates mode="CanonicalObject" select="."/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-delete-object" match="AAAJWTGenerator">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:value-of select="concat('no jwt-generator ', dpfunc:quoesc(@name), $eol)"/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

      <!-- Social Login Policy -->
    <xsl:template mode="cli-object" match="SocialLoginPolicy">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:apply-templates mode="CanonicalObject" select="."/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-delete-object" match="SocialLoginPolicy">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:value-of select="concat('no social-login-policy ', dpfunc:quoesc(@name), $eol)"/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>
    
    <xsl:template match="args[action='AuthCookieCacheDelete']" mode="cli-actions">
        <xsl:value-of select="concat(
                              'configure terminal', $eol,
                              'crypto', $eol,
                              'authcookie-cache-delete ',
                              dpfunc:quoesc(Key), $eol)"/>
    </xsl:template>


    <!-- ************************************************************ -->
    <!-- MQGW -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-object" match="MQGW">
        <xsl:call-template name="available-open">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>

        <xsl:value-of select="concat($eol, 'mq-node', ' ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat(' reset', $eol)"/>
        </xsl:if>

        <xsl:apply-templates mode="MQGW"/>
        <xsl:value-of select="concat('exit', $eol)"/>
        <xsl:call-template name="available-close">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>

    </xsl:template>

    <xsl:template mode="MQGW" match="Client">
        <xsl:if test="(string-length()!=0)">
            <xsl:if test="(../Direction='HTTP2MQ') or ((../Direction='') and (ClientTransportType='mq'))">
                <xsl:value-of select="concat(' client mq ', ClientGetQueue, ' ', ClientPutQueue, $eol)"/>
            </xsl:if>
            <xsl:if test="(../Direction='MQ2HTTP') or ((../Direction='') and (ClientTransportType='http'))">
                <xsl:value-of select="concat(' client http ', ClientPort, $eol)"/>
            </xsl:if>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="MQGW" match="Server">
        <xsl:if test="(string-length()!=0)">
            <xsl:if test="(../Direction='MQ2HTTP') or ((../Direction='') and (ServerTransportType='mq'))">
                <xsl:value-of select="concat(' server mq ', ServerGetQueue, ' ', ServerPutQueue, $eol)"/>
            </xsl:if>
            <xsl:if test="(../Direction='HTTP2MQ') or ((../Direction='') and (ServerTransportType='http'))">
                <xsl:value-of select="concat(' server http ', ServerPort, $eol)"/>
            </xsl:if>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="MQGW" match="*">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- Intrinsic LogLabel -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-object" match="LogLabel[@intrinsic='true']"/>

    <!-- ************************************************************ -->
    <!-- LogTarget -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-object" match="LogTarget">
        <xsl:choose>
            <!-- if 'default-log' - only allow changes to event and object subscription -->
            <xsl:when test="(@name='default-log')">
                <xsl:if test="($delta-config=true())">
                    <xsl:value-of select="concat($eol, 'no logging object default-log *', $eol )"/>
                    <xsl:value-of select="concat($eol, 'no logging event default-log *', $eol )"/>
                    <xsl:value-of select="concat($eol, 'no logging eventcode default-log *', $eol )"/>
                    <xsl:value-of select="concat($eol, 'no logging eventfilter default-log *', $eol )"/>
                    <xsl:value-of select="concat($eol, 'no logging ipfilter default-log *', $eol )"/>
                    <xsl:value-of select="concat($eol, 'no logging trigger default-log *', $eol )"/>
                </xsl:if>
                <xsl:apply-templates mode="DefaultLogTarget"/>
            </xsl:when>

            <xsl:otherwise>
                <xsl:value-of select="concat($eol, 'logging target ', dpfunc:quoesc(@name), $eol)"/>
                <xsl:if test="($delta-config=true())">
                    <xsl:value-of select="concat($eol, '  reset', $eol)"/>
                </xsl:if>
                <xsl:apply-templates mode="LogTarget"/>
                <xsl:value-of select="concat('exit', $eol)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- suppress internal property -->
    <xsl:template mode="LogTarget" match="Stream"/>

    <xsl:template mode="LogTarget" match="RemoteAddress">
        <xsl:if test="(string-length()!=0)">
            <xsl:value-of select="concat('  remote-address ', dpfunc:quoesc(text()), ' ', dpfunc:quoescne(../RemotePort), $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="LogTarget" match="RemotePort"/>

    <xsl:template mode="LogTarget" match="SigningMode">
        <xsl:if test="(text()='on')">
            <xsl:value-of select="concat('  sign ', ../IdentCredential, ' ', dpfunc:quoescne(../SignAlgorithm), $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="LogTarget" match="IdentCredential"/>
    <xsl:template mode="LogTarget" match="SignAlgorithm"/>

    <xsl:template mode="LogTarget" match="EncryptMode">
        <xsl:if test="(text()='on')">
            <xsl:value-of select="concat('  encrypt ', dpfunc:quoesc(../Cert), ' ', dpfunc:quoescne(../EncryptAlgorithm), $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="LogTarget" match="Cert"/>
    <xsl:template mode="LogTarget" match="EncryptAlgorithm"/>

    <xsl:template mode="LogTarget" match="RemoteLogin">
        <xsl:if test="(../ArchiveMode/text()='upload') and not (../UploadMethod/text()='smtp')">
            <xsl:value-of select="concat('  remote-login ', dpfunc:quoesc(text()))"/>
            <xsl:if test="(../RemotePassword) and ($delta-config=true()) and not(../RemotePassword/text()='')">
                <xsl:value-of select="concat(' ', dpfunc:quoesc(../RemotePassword))"/>
            </xsl:if>
            <xsl:value-of select="concat($eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="LogTarget" match="RemotePassword"/>

    <xsl:template mode="LogTarget" match="LogEvents">
        <xsl:value-of select="concat( '  event ', dpfunc:quoesc(Class), ' ', dpfunc:quoescne(Priority), $eol )"/>
    </xsl:template>

    <xsl:template mode="LogTarget" match="LogObjects">
        <xsl:value-of select="concat( '  object ', dpfunc:quoesc(Class), ' ', dpfunc:quoescne(Object), $eol )"/>
        <xsl:if test="FollowReferences='on'">
            <xsl:call-template name="Log-ReferenceChain">
                <xsl:with-param name="objClass" select="Class"/>
                <xsl:with-param name="objName" select="Object"/>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="DefaultLogTarget" match="LogObjects">
        <xsl:value-of select="concat( 'logging object default-log',
                                      ' ', dpfunc:quoesc(Class),
                                      ' ', dpfunc:quoesc(Object),
                                      ' ', dpfunc:quoesc(FollowReferences), $eol )"/>
    </xsl:template>

    <xsl:template mode="DefaultLogTarget" match="LogEvents[not(Class = 'webgui')]">
        <xsl:value-of select="concat( 'logging event default-log ', dpfunc:quoesc(Class), ' ', dpfunc:quoesc(Priority), $eol )"/>
    </xsl:template>

    <xsl:template mode="DefaultLogTarget" match="LogEventCode">
        <xsl:value-of select="concat( 'logging eventcode default-log ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>

    <xsl:template mode="DefaultLogTarget" match="LogEventFilter">
        <xsl:value-of select="concat( 'logging eventfilter default-log ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>

    <xsl:template mode="DefaultLogTarget" match="LogIPFilter">
        <xsl:value-of select="concat( 'logging ipfilter default-log ', dpfunc:quoesc(IPAddress), $eol )"/>
    </xsl:template>

    <xsl:template mode="DefaultLogTarget" match="LogTriggers">
        <xsl:value-of select="concat('logging trigger default-log', 
                                     ' ', dpfunc:quoesc(ID),
                                     ' ', dpfunc:quoesc(Expression), 
                                     ' ', dpfunc:quoesc(OnlyOnce),
                                     ' ', dpfunc:quoesc(StopProcessing),
                                     ' ', dpfunc:quoesc(Command), $eol)"/>
    </xsl:template>

    <xsl:template name="Log-ReferenceChain">
        <xsl:param name="objClass" select="''"/>
        <xsl:param name="objName" select="''"/>
        <xsl:param name="prefix" select="'  '"/>
        <xsl:param name="target" select="''"/>
        <xsl:param name="visitedConfig">
            <xsl:element name="processed-config-nodes"/>
        </xsl:param>

        <!-- Update visited config -->
        <xsl:variable name="updatedVisitedConfig">
            <processed-config-nodes>
                <processed-config-node>
                    <objClass><xsl:value-of select="$objClass"/></objClass>
                    <objName><xsl:value-of select="$objName"/></objName>
                </processed-config-node>
                <xsl:copy-of select="$visitedConfig/processed-config-nodes/processed-config-node"/>
            </processed-config-nodes>
        </xsl:variable>

        <!-- intermediate variables -->
        <xsl:variable name="all-props">
            <xsl:copy-of select="dpfunc:schema-object-props($objClass)"/>
        </xsl:variable>
        
        <!-- complex properties -->
        <xsl:variable name="comp-props">
            <xsl:copy-of select="$schema-complex-types/self::type 
                                 [@name=$all-props/property/@type] 
                                 /properties/property"/>
        </xsl:variable>

        <!-- reference properties (@reftype is common for all flavors -->
        <xsl:variable name="ref-props">
            <xsl:copy-of select="($all-props|$comp-props)/property
                                  [@reftype]"/>
        </xsl:variable>

        <xsl:variable name="regexp-objName" select="concat('^\s*',$objName,'\s*$')"/>

        <!-- Object names are case insensitive, make sure they are treated correctly -->
        <xsl:for-each select="$cli-existing/response/operation[@type='get-config']
                  /configuration/*[(local-name()=$objClass) and regexp:test(@name,$regexp-objName,'i')]/descendant-or-self::*[local-name()=$ref-props/property/@name and text()]">
            
            <!-- Use the class attirbute when it exists.  Though there are cases where it is not present so we need to make sure
                 we know if the property is a reference -->
            <xsl:variable name="refclass">
                <xsl:choose>
                    <xsl:when test="@class">
                        <xsl:value-of select="@class"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:variable name="propname" select="local-name()"/>
                        <xsl:value-of select="$ref-props/property[@name=$propname]/@reftype"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>

            <xsl:variable name="instanceName" select="string(.)"/>
            <xsl:variable name="regexp-instanceName" select="concat('^\s*',$instanceName,'\s*$')"/>

            <xsl:choose>
                <!-- loop detection: test if we've already visited the specified node -->
                <xsl:when test="$visitedConfig/processed-config-nodes/processed-config-node[objClass = $refclass and regexp:test(objName,$regexp-instanceName,'i')]"></xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat( $prefix, 'object ', $target ,$refclass, ' ', $instanceName, $eol )"/>
                    <xsl:call-template name="Log-ReferenceChain">
                        <xsl:with-param name="objClass" select="$refclass"/>
                        <xsl:with-param name="objName" select="$instanceName"/>
                        <xsl:with-param name="prefix" select="$prefix"/>
                        <xsl:with-param name="target" select="$target"/>
                        <xsl:with-param name="visitedConfig" select="$updatedVisitedConfig"/>
                    </xsl:call-template>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each> 
    </xsl:template>

    <xsl:template mode="LogTarget" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- SSHService -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-delete-object" match="SSHService"/>

    <xsl:template mode="cli-object" match="SSHService">
        <!-- enable/disable -->
        <xsl:choose>
            <xsl:when test="(mAdminState='enabled')">
                <xsl:value-of select="concat($eol, 'ssh ', dpfunc:quoesc(LocalAddress), ' ', dpfunc:quoescne(LocalPort), $eol)"/>
            </xsl:when>
            <xsl:when test="(mAdminState='disabled')">
                <xsl:value-of select="concat($eol, 'no ssh', $eol)"/>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- ACL -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-delete-object" match="AccessControlList">
        <xsl:value-of select="concat($eol, 'no acl ', dpfunc:quoesc(@name), $eol)"/>
    </xsl:template>

    <xsl:template mode="cli-object" match="AccessControlList">
        <!-- preserve the ACL even if SSH is disabled -->
        <xsl:value-of select="concat($eol, 'acl ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="ACLEntry" select="*"/>
        <xsl:value-of select="concat('exit', $eol)"/>
    </xsl:template>

    <xsl:template mode="ACLEntry" match="AccessControlEntry">
        <xsl:value-of select="concat('  ', Access, ' ', dpfunc:quoescne(Address), $eol)"/>
    </xsl:template>

    <xsl:template mode="ACLEntry" match="mAdminState">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- Packet Capture -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-delete-object" match="xmltrace"/>

    <xsl:template mode="cli-object" match="xmltrace">
        <!-- enable/disable -->
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat($eol, 'file-capture ', dpfunc:quoesc(Mode), $eol)"/>
        </xsl:if>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- Statistics -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-delete-object" match="Statistics"/>

    <xsl:template mode="cli-object" match="Statistics">
        <!-- enable/disable -->
        <xsl:choose>
            <xsl:when test="(mAdminState='enabled')">
                <xsl:value-of select="concat($eol, 'statistics', $eol)"/>
            </xsl:when>
            <xsl:when test="(mAdminState='disabled')">
                <xsl:value-of select="concat($eol, 'no statistics', $eol)"/>
            </xsl:when>
        </xsl:choose>
        <xsl:apply-templates mode="Statistics"/>
    </xsl:template>

    <xsl:template mode="Statistics" match="LoadInterval">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
            <xsl:with-param name="Indent" select="$eol"/>
            <xsl:with-param name="forceDefault" select="$delta-config"/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- Error Report Settings -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-object" match="ErrorReportSettings">
        <xsl:value-of select="concat($eol, 'failure-notification', $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="ErrorReportSettings"/>
        <xsl:value-of select="concat('exit', $eol)"/>

        <xsl:if test="$delta-config=false()">
            <xsl:if test="(mAdminState='enabled')">
                <xsl:choose>
                    <xsl:when test="(UploadReport = 'on')">
                    <!-- When upload is enabled, this is considered the new behavior and
                         the decision to upload an error-report is determined from drErrorReport.cpp -->
                    </xsl:when>
                    <xsl:when test="(UseSmtp = 'on')">
                        <xsl:choose>
                            <xsl:when test="EmailSenderAddress != ''">
                                <xsl:value-of select="concat($eol, 
                                                     'send error-report', 
                                                     ' ', dpfunc:quoesc(SmtpServer),
                                                     ' ', dpfunc:quoesc(LocationIdentifier),
                                                     ' ', dpfunc:quoesc(EmailAddress), 
                                                     ' ', dpfunc:quoesc(EmailSenderAddress), $eol)"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="concat($eol, 
                                                     'send error-report', 
                                                     ' ', dpfunc:quoesc(SmtpServer),
                                                     ' ', dpfunc:quoesc(LocationIdentifier),
                                                     ' ', dpfunc:quoesc(EmailAddress), $eol)"/>
                            </xsl:otherwise>
                         </xsl:choose>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="$eol"/>
                        <xsl:if test="(AlwaysOnStartup = 'off')">
                            <xsl:value-of select="concat('%if% isfile temporary:///backtrace', $eol)"/>
                        </xsl:if>
                        <xsl:value-of select="concat('save error-report', $eol)"/>
                        <xsl:if test="(AlwaysOnStartup = 'off')">
                            <xsl:value-of select="concat('%endif%', $eol)"/>
                        </xsl:if>
                        <xsl:value-of select="$eol"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:if>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="ErrorReportSettings" match="mAdminState">
      <xsl:value-of select="concat('  admin-state ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="ErrorReportSettings" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- HTTPUserAgent -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-delete-object" match="HTTPUserAgent">
      <xsl:value-of select="concat($eol, 'no user-agent ', dpfunc:quoesc(@name), $eol)"/>
    </xsl:template>

    <xsl:template mode="cli-object" match="HTTPUserAgent">
        <xsl:value-of select="concat($eol, 'user-agent ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="HTTPUserAgent"/>
        <xsl:value-of select="concat('exit', $eol)"/>
    </xsl:template>

    <xsl:template mode="HTTPUserAgent" match="ProxyPolicies">
        <xsl:value-of select="concat('  proxy ', dpfunc:quoesc(RegExp))"/>
        <xsl:choose>
            <xsl:when test="(Skip='off')">
                <xsl:value-of select="concat(' ', dpfunc:quoesc(RemoteAddress), ' ', dpfunc:quoescne(RemotePort))"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat(' none')"/>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:value-of select="concat($eol)"/>
    </xsl:template>

    <xsl:template mode="HTTPUserAgent" match="SSLPolicies">
        <!-- Use old CLI format when no configuration type is specified, else use the new format... -->
        <xsl:choose>
            <xsl:when test="dpfunc:quoesc(SSLClientConfigType)='&quot;&quot;'">
                <xsl:value-of select="concat('  ssl ', dpfunc:quoesc(RegExp), ' ',
                                      dpfunc:quoesc(SSLProxyProfile), $eol)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat('  ssl ', dpfunc:quoesc(RegExp), ' ',
                                      dpfunc:quoesc(SSLProxyProfile), ' ',
                                      dpfunc:quoesc(SSLClientConfigType), ' ',
                                      dpfunc:quoesc(SSLClient), $eol)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template mode="HTTPUserAgent" match="BasicAuthPolicies">
        <xsl:value-of select="concat('  basicauth ', dpfunc:quoesc(RegExp), ' ',
                              dpfunc:quoesc(UserName), ' ',
                              dpfunc:quoesc(Password), ' ',
                              dpfunc:quoesc(PasswordAlias), $eol)"/>
    </xsl:template>

    <xsl:template mode="HTTPUserAgent" match="SoapActionPolicies">
        <xsl:value-of select="concat('  soapaction ', dpfunc:quoesc(RegExp), ' ',
                              dpfunc:quoesc(SoapAction), $eol)"/>
    </xsl:template>

    <xsl:template mode="HTTPUserAgent" match="AllowCompressionPolicies">
        <xsl:value-of select="concat('  compression-policy ', dpfunc:quoesc(RegExp), ' ',
                              dpfunc:quoesc(AllowCompression), $eol)"/>
    </xsl:template>

    <xsl:template mode="HTTPUserAgent" match="Restrict10Policies">
        <xsl:value-of select="concat('  restrict-http-policy ', dpfunc:quoesc(RegExp), ' ',
                              dpfunc:quoesc(Restrict10), $eol)"/>
    </xsl:template>

    <xsl:template mode="HTTPUserAgent" match="AddHeaderPolicies">
        <xsl:value-of select="concat('  add-header-policy ', dpfunc:quoesc(RegExp), ' ',
                              dpfunc:quoesc(AddHeader), ' ', dpfunc:quoesc(AddValue), $eol)"/>
    </xsl:template>

    <xsl:template mode="HTTPUserAgent" match="UploadChunkedPolicies">
        <xsl:value-of select="concat('  chunked-uploads-policy ', dpfunc:quoesc(RegExp), ' ',
                              dpfunc:quoesc(UploadChunked), $eol)"/>
    </xsl:template>

   <xsl:template mode="HTTPUserAgent" match="*">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
            <xsl:with-param name="Indent" select="'  '"/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- WebGUI -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-delete-object" match="WebGUI"/>

    <xsl:template mode="cli-object" match="WebGUI">
        <xsl:choose>
            <xsl:when test="(SaveConfigOverwrites='on')">
                <xsl:value-of select="concat($eol, 'save-config overwrite', $eol)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat($eol, 'no save-config overwrite', $eol)"/>
            </xsl:otherwise>
        </xsl:choose>

        <xsl:value-of select="concat($eol, 'web-mgmt', $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="WebGUI"/>
        <xsl:value-of select="concat('exit', $eol)"/>
    </xsl:template>

    <!-- local-address + local-port properties -->
    <xsl:template mode="WebGUI" match="LocalAddress">
        <xsl:value-of select="concat('  local-address ', dpfunc:quoesc(text()), ' ', dpfunc:quoescne(../LocalPort), $eol)"/>
    </xsl:template>

    <xsl:template mode="WebGUI" match="LocalPort"/>

    <xsl:template mode="WebGUI" match="mAdminState">
      <xsl:value-of select="concat('  admin-state ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="WebGUI" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- WebB2BViewer -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-delete-object" match="WebB2BViewer"/>

    <xsl:template mode="cli-object" match="WebB2BViewer">
        <xsl:call-template name="available-open">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>
        <xsl:value-of select="concat($eol, 'b2b-viewer-mgmt', $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="WebB2BViewer"/>
        <xsl:value-of select="concat('exit', $eol)"/>
        <xsl:call-template name="available-close">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>
    </xsl:template>

    <!-- local-address + local-port properties -->
    <xsl:template mode="WebB2BViewer" match="LocalAddress">
        <xsl:value-of select="concat('  local-address ', dpfunc:quoesc(text()), ' ', dpfunc:quoescne(../LocalPort), $eol)"/>
    </xsl:template>

    <xsl:template mode="WebB2BViewer" match="LocalPort"/>

    <xsl:template mode="WebB2BViewer" match="mAdminState">
      <xsl:value-of select="concat('  admin-state ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="WebB2BViewer" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- MgmtInterface -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-delete-object" match="MgmtInterface"/>

    <xsl:template mode="cli-object" match="MgmtInterface">
        <xsl:value-of select="concat($eol, 'xml-mgmt', $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="XMLMgmt"/>
        <xsl:value-of select="concat('exit', $eol)"/>
    </xsl:template>

    <!-- local-address + local-port properties -->
    <xsl:template mode="XMLMgmt" match="LocalAddress">
        <xsl:value-of select="concat('  local-address ', dpfunc:quoesc(text()), ' ', dpfunc:quoescne(../LocalPort), $eol)"/>
    </xsl:template>

    <xsl:template mode="XMLMgmt" match="LocalPort"/>

    <xsl:template mode="XMLMgmt" match="mAdminState">
      <xsl:value-of select="concat('  admin-state ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="XMLMgmt" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- RestMgmtInterface -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-delete-object" match="RestMgmtInterface"/>

    <xsl:template mode="cli-object" match="RestMgmtInterface">
        <xsl:value-of select="concat($eol, 'rest-mgmt', $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="RESTMgmt"/>
        <xsl:value-of select="concat('exit', $eol)"/>
    </xsl:template>

    <!-- local-address + local-port properties -->
    <xsl:template mode="RESTMgmt" match="LocalAddress">
        <xsl:value-of select="concat('  local-address ', dpfunc:quoesc(text()), ' ', dpfunc:quoescne(../LocalPort), $eol)"/>
    </xsl:template>

    <xsl:template mode="RESTMgmt" match="LocalPort"/>

    <xsl:template mode="RESTMgmt" match="mAdminState">
      <xsl:value-of select="concat('  admin-state ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="RESTMgmt" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- http proxy templates -->
    <!-- ************************************************************ -->

    <xsl:template name="HTTPProxyServiceProperties">
        <xsl:param name="identifier" select="''"/>
        <xsl:value-of select="concat($eol, 'http ', dpfunc:quoesc(@name), ' ', $identifier, $eol)"/>
        <xsl:apply-templates mode="HTTPProxyService"/>
        <xsl:value-of select="concat('exit', $eol )"/>
    </xsl:template>

    <!-- http header injection -->
    <xsl:template mode="HTTPProxyService" match="HeaderInjection">
        <xsl:value-of select="concat('  inject ', Direction,
                                     ' ', dpfunc:quoesc(HeaderTag),
                                     ' ', dpfunc:quoesc(HeaderTagValue), $eol)"/>
    </xsl:template>

    <!-- http header suppress -->
    <xsl:template mode="HTTPProxyService" match="HeaderSuppression">
        <xsl:value-of select="concat('  suppress ', Direction,
                                     ' ', dpfunc:quoesc(HeaderTag), $eol)"/>
    </xsl:template>

    <!-- http version -->
    <xsl:template mode="HTTPProxyService" match="HTTPVersion">
        <xsl:value-of select="concat('  version ', dpfunc:quoesc(Front), ' ', dpfunc:quoescne(Back), $eol)"/>
    </xsl:template>

    <!-- host rewriting -->
    <xsl:template mode="HTTPProxyService" match="DoHostRewrite">
        <xsl:value-of select="concat('  host-rewriting ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="HTTPProxyService" match="HTTPIncludeResponseTypeEncoding">
        <!-- enable/disable -->
        <xsl:if test="(text()='on')">
                <xsl:value-of select="concat('  include-response-type-encoding', $eol)"/>
        </xsl:if>
        <xsl:if test="(text()='off')">
                <xsl:value-of select="concat('  no include-response-type-encoding', $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="HTTPProxyService" match="AlwaysShowErrors">
        <!-- enable/disable -->
        <xsl:if test="(text()='on')">
                <xsl:value-of select="concat('  always-show-errors', $eol)"/>
        </xsl:if>
        <xsl:if test="(text()='off')">
                <xsl:value-of select="concat('  no always-show-errors', $eol)"/>
        </xsl:if>
    </xsl:template>


    <xsl:template mode="HTTPProxyService" match="DisallowGet">
        <!-- enable/disable -->
        <xsl:if test="(text()='on')">
                <xsl:value-of select="concat('  disallow-get', $eol)"/>
        </xsl:if>
        <xsl:if test="(text()='off')">
                <xsl:value-of select="concat('  no disallow-get', $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="HTTPProxyService" match="DisallowEmptyResponse">
        <!-- enable/disable -->
        <xsl:if test="(text()='on')">
                <xsl:value-of select="concat('  disallow-empty-reply', $eol)"/>
        </xsl:if>
        <xsl:if test="(text()='off')">
                <xsl:value-of select="concat('  no disallow-empty-reply', $eol)"/>
        </xsl:if>
    </xsl:template>


    <!-- remaining properties in external http submenu -->
    <xsl:template mode="HTTPProxyService" match="HTTPTimeout|HTTPPersistTimeout|SuppressHTTPWarnings
                                                 |HTTPCompression|HTTPPersistentConnections|HTTPClientIPLabel
                                                 |HTTPProxyHost|HTTPProxyPort|HTTPLogCorIDLabel">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="'HTTPProxyService'"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="text()"/>
            <xsl:with-param name="Indent" select="'  '"/>
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template mode="HTTPProxyService" match="DoChunkedUpload">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>
    
    <xsl:template mode="HTTPProxyService" match="*"/>

    <!-- ************************************************************ -->
    <!-- domain templates -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-object" match="Domain">
        <xsl:if test="not(@name='default')">
            <xsl:apply-templates mode="CanonicalObject" select="."/>
        </xsl:if>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- DNSNameservice templates -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-delete-object" match="DNSNameService"/>

    <xsl:template mode="cli-object" match="DNSNameService">
        <xsl:value-of select="concat($eol, 'dns', $eol)"/>
        <xsl:if test="($delta-config=true())">
        <xsl:value-of select="concat('  reset',$eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="DNSNameService"/>
    <xsl:value-of select="concat('exit', $eol)"/>
    </xsl:template>

    <xsl:template mode="DNSNameService" match="SearchDomains">
        <xsl:value-of select="concat('  search-domain ', dpfunc:quoesc(SearchDomain), $eol)"/>
    </xsl:template>

    <xsl:template mode="DNSNameService" match="NameServers">
        <!-- hardwire the hidden Flags property to its default value -->
        <xsl:value-of select="concat('  name-server ', dpfunc:quoesc(IPAddress), ' ', dpfunc:quoesc(UDPPort), ' ', dpfunc:quoesc(TCPPort), ' 0 ', dpfunc:quoescne(MaxRetries), $eol)"/>
    </xsl:template>

    <xsl:template mode="DNSNameService" match="StaticHosts">
        <xsl:value-of select="concat('  static-host ', dpfunc:quoesc(Hostname), ' ', dpfunc:quoescne(IPAddress), $eol)"/>
    </xsl:template>

    <xsl:template mode="DNSNameService" match="mAdminState|UserSummary|IPPreference|ForceIPPreference|LoadBalanceAlgorithm|MaxRetries|Timeout">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- SystemSettings templates -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-delete-object" match="SystemSettings"/>

    <!-- ************************************************************ -->
    <!-- autogenerated object templates (low priority) -->
    <!-- ************************************************************ -->

    <!-- auto-generated config -->
    <xsl:template mode="cli-object" priority="-100" match="*[$config-objects-index/self::object/@name=local-name()]">
        <xsl:choose>
            <xsl:when test="$config-objects-index/self::object[@name=local-name() and @custom-cli='true']">
                <xsl:message dpe:type="mgmt" dpe:priority="warn" dpe:id="{$DPLOG_WEBGUI_NO_CUSTOM_CLI}">
                    <dpe:with-param value="{local-name()}"/>
                </xsl:message>
                </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="CanonicalObject" select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- canonical object templates -->
    <!-- ************************************************************ -->

    <xsl:template mode="CanonicalObject" match="*">
        <xsl:param name="noConditional" select="false()"/>

        <xsl:variable name="objName" select="local-name()"/>
        <xsl:variable name="pNode" select="$config-objects-index/self::object[@name=$objName]"/>

        <xsl:variable name="alias" select="$pNode/cli-alias"/>

        <!-- skip unpersisted objects in save config mode -->
        <xsl:if test="not($pNode/@persisted='false') or $delta-config">

            <!-- singletons do not have name serialized -->
            <xsl:variable name="singleton_or_name">
                <xsl:if test="not($pNode/@singleton = 'true' or $pNode/@domain-singleton = 'true')">
                    <xsl:value-of select="concat(' ', dpfunc:quoesc(@name))"/>
                </xsl:if>
            </xsl:variable>

            <xsl:if test="$noConditional = false()">
                <!-- start object conditional -->
                <xsl:call-template name="available-open">
                    <xsl:with-param name="name" select="local-name()"/>
                    <xsl:with-param name="pNode" select="$pNode"/>
                </xsl:call-template>
            </xsl:if>

            <!-- enter object mode -->
            <xsl:value-of select="concat($eol, $alias, $singleton_or_name, $eol)"/>

            <xsl:if test="($delta-config=true()) and ((./@reset!='false') or not(./@reset))">
                <xsl:value-of select="concat('  reset', $eol)"/>
            </xsl:if>

            <!-- object with non-distinct vector property -->
            <xsl:if test="(not(@reset='false') and $pNode//property[@vector='true' and @distinct='false'])">
                <xsl:for-each select="$pNode//property[@vector='true' and @distinct='false']">
                   <xsl:value-of select="concat('  no ',./cli-alias,$eol)"/>
                </xsl:for-each>
            </xsl:if>

            <!-- serialize properties -->
            <xsl:apply-templates mode="CanonicalProperty"/>

            <!-- exit object mode -->
            <xsl:value-of select="concat('exit', $eol)"/>

            <xsl:if test="$noConditional = false()">
                <!-- end object conditional -->
                <xsl:call-template name="available-close">
                    <xsl:with-param name="name" select="local-name()"/>
                    <xsl:with-param name="pNode" select="$pNode"/>
                </xsl:call-template>
            </xsl:if>

        </xsl:if>

    </xsl:template>

    <!-- pseudo property that is really a container for other props -->
    <xsl:template mode="CanonicalProperty" match="*[MetaItemVector]">
        <xsl:for-each select=".//MetaItem">
            <xsl:choose>
                <xsl:when test="DataSource">
                    <xsl:value-of select="concat('  meta-item ', dpfunc:quoesc(MetaCategory), ' ', dpfunc:quoesc(MetaName), ' ', dpfunc:quoesc(DataSource), $eol)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat('  meta-item ', dpfunc:quoesc(MetaCategory), ' ', dpfunc:quoesc(MetaName), $eol)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>

    <!-- canonical property -->
    <xsl:template mode="CanonicalProperty" match="*">
        <!-- Get the license off the property element of the specified object -->
        <xsl:variable name="propertyName"    select="name()" />
        <xsl:variable name="objectName"      select="name(..)" />
        <xsl:variable name="objectElement" select="$config-objects-index/self::object[@name=$objectName]" />
        <xsl:variable name="licensed">    
            <xsl:call-template name="fetchLicense">
                <xsl:with-param name="objectName" select="$objectName"/>
                <xsl:with-param name="propertyName" select="$propertyName"/>
            </xsl:call-template>
        </xsl:variable>

        <!-- Check to see if the property is licensed on this appliance -->
        <xsl:variable name="value-is-licensed">
           <xsl:call-template name="is-licensed">
               <xsl:with-param name="featureToCheck" select="$licensed"/>
           </xsl:call-template>
        </xsl:variable>

        <!-- Only apply properties licensed on the appliance -->
        <xsl:if test="($value-is-licensed = 'true')">
           <xsl:apply-templates mode="DefaultProperty" select=".">
              <xsl:with-param name="objName" select="name(..)"/>
              <xsl:with-param name="pName" select="name()"/>
              <xsl:with-param name="pValue" select="text()"/>
              <xsl:with-param name="pProp" select="."/>
              <xsl:with-param name="Indent" select="'  '"/>
           </xsl:apply-templates>
        </xsl:if>
    </xsl:template>

    <!-- fetch the licensed feature for a property if any -->
    <xsl:template name="fetchLicense">
        <xsl:param name="objectName" />
        <xsl:param name="propertyName" />
        <xsl:variable name="propertyElement" select="$config-objects-index/self::object[@name=$objectName]/properties/property[@name=$propertyName]" />
        <xsl:choose>
            <xsl:when test="$propertyName='mAdminState'">
                <xsl:text />
            </xsl:when>
            <xsl:when test="$propertyElement">
                <xsl:value-of select="($propertyElement/@licensed)" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="parentObjectName">
                    <xsl:variable name="derived" select="$config-objects-index/self::object[@name=$objectName]/../.." />
                    <xsl:if test="$derived/derived-objects">
                        <xsl:value-of select="$derived/@name"/>
                    </xsl:if>
                </xsl:variable>
                <xsl:choose>
                    <xsl:when test="$parentObjectName='ConfigBase'">
                        <xsl:text />
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:call-template name="fetchLicense">
                            <xsl:with-param name="objectName" select="$parentObjectName"/>
                            <xsl:with-param name="propertyName" select="$propertyName"/>
                        </xsl:call-template>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- behind firewall isLicensed template -->
    <xsl:template name="is-licensed">
        <xsl:param name="featureToCheck" />

        <!-- Try webgui:///Licenses.xml first and then /drouter/webgui/Licenses.xml -->
        <xsl:variable name="features1">
           <xsl:copy-of select="document('webgui:///Licenses.xml')"/>       
        </xsl:variable>
        <xsl:variable name="features">
           <xsl:choose>
              <xsl:when test="not($features1) or $features1='' ">
                 <xsl:copy-of select="document('/drouter/webgui/Licenses.xml')"/>
              </xsl:when>
              <xsl:otherwise>
                 <xsl:copy-of select="$features1"/>
              </xsl:otherwise>
           </xsl:choose>
        </xsl:variable>

        <!-- If no feature to check.... return true
             Else if enablement and availability "Yes"... return true
             Else if not enabled and/or available... return false -->
        <xsl:choose>
           <xsl:when test="not($featureToCheck) or $featureToCheck=''"> 
              <xsl:value-of select="true()" />
           </xsl:when>
           <xsl:otherwise>
              <xsl:variable name="enabled" select="$features/features/feature[@name=$featureToCheck]/@enabled" />
              <xsl:variable name="available" select="$features/features/feature[@name=$featureToCheck]/@available" />
              <xsl:choose>
                 <xsl:when test="$available='Yes' and $enabled='Yes'"> 
                    <xsl:value-of select="true()" />
                 </xsl:when>
                 <xsl:otherwise>
                    <xsl:value-of select="false()" />
                 </xsl:otherwise>
              </xsl:choose>
           </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

  <!-- ************************************************************ -->
  <!-- Generic helper templates -->
  <!-- ************************************************************ -->

  <!-- issues %if% available prelude for first object of its kind -->
  <!-- NOTE must be called with config object as context node. -->
  <xsl:template name="available-open">
      <xsl:param name="name" select="local-name()"/>
      <xsl:param name="pNode" select="$config-objects-index/self::object[@name=$name]"/>
      <xsl:param name="alias" select="$pNode/cli-alias"/>

      <xsl:variable name="isFirst" select="not(preceding-sibling::*[1][local-name()=$name])"/>

      <xsl:if test="$isFirst">
          <xsl:value-of select="concat($eol, '%if% available ', dpfunc:quoesc($alias), $eol)"/>
      </xsl:if>
  </xsl:template>

  <xsl:template name="available-close">
      <xsl:param name="name" select="local-name()"/>
      <xsl:param name="pNode" select="$config-objects-index/self::object[@name=$name]"/>

      <xsl:variable name="isLast" select="not(following-sibling::*[1][local-name()=$name])"/>

      <xsl:if test="$isLast">
          <xsl:value-of select="concat($eol, '%endif%', $eol)"/>
      </xsl:if>
  </xsl:template>

  <func:function name="dpfunc:esc">
      <xsl:param name="value"/>

      <!-- cli commands can't have carriage-returns or line-feeds in them (in any order or combination) -->
      <!-- don't use normalize-space() since it would alter with string literals with multiple spaces in them -->
      <xsl:variable name="find-crlf"><xsl:text>[\r\n]+</xsl:text></xsl:variable>
      <xsl:variable name="replace-crlf"><xsl:text> </xsl:text></xsl:variable>
      <xsl:variable name="stripped-value" select="regexp:replace($value, $find-crlf, 'g', $replace-crlf)"/>

      <xsl:variable name="find"><xsl:text>([\\"])</xsl:text></xsl:variable>
      <xsl:variable name="replace"><xsl:text>\$1</xsl:text></xsl:variable>
      <xsl:variable name="escaped-value" select="regexp:replace($stripped-value, $find, 'g', $replace)"/>

      <func:result select="$escaped-value"/>

  </func:function>

  <!-- if you're going to quote a string, you must escape it, in case there is a quote in it -->
  <func:function name="dpfunc:quoesc">
      <xsl:param name="value"/>
      <xsl:variable name="quoted-escaped-value" select="concat($quote, dpfunc:esc($value), $quote)"/>
      <func:result select="$quoted-escaped-value"/>
  </func:function>

  <!-- quote escape non-empty string -->
  <func:function name="dpfunc:quoescne">
      <xsl:param name="value"/>
      <xsl:variable name="quoted-escaped-value">
          <xsl:choose>
          <xsl:when test="($value!='')">
              <xsl:value-of select="dpfunc:quoesc($value)"/>
          </xsl:when>
          <xsl:otherwise>
              <xsl:text></xsl:text>
          </xsl:otherwise>
      </xsl:choose>
      </xsl:variable>
      <func:result select="$quoted-escaped-value"/>
  </func:function>

    <func:function name="dpfunc:bitmap-to-string">
      <xsl:param name="bitmap"/>
      <xsl:variable name="result">
        <xsl:for-each select="$bitmap/*[.='on']">
          <xsl:value-of select="local-name()"/>
          <xsl:if test="position() != last()">+</xsl:if>
        </xsl:for-each>
      </xsl:variable>
      <func:result select="$result"/>
    </func:function>

  <!-- this is the default delete template, which works for objects
       which take 'no <cli-alias> @name' syntax -->

  <xsl:template mode="cli-delete-object" match="*" priority="-100">
      <xsl:variable name="objName" select="local-name()"/>
      <xsl:variable name="pNode" select="$config-objects-index/self::object[@name=$objName]"/>
      <xsl:choose>
          <xsl:when test="(not($pNode/cli-alias) or $pNode/cli-alias='')">
              <xsl:message dpe:type="mgmt" dpe:priority="warn" dpe:id="{$DPLOG_WEBGUI_NO_CUSTOM_CLI_DELETE}">
                    <dpe:with-param value="{$objName}"/>
              </xsl:message>
          </xsl:when>
          <xsl:when test="($pNode/@singleton='true' or $pNode/@domain-singleton='true')">
              <xsl:value-of select="concat('no ', $pNode/cli-alias, $eol)"/>
          </xsl:when>
          <xsl:otherwise>
              <xsl:value-of select="concat('no ', $pNode/cli-alias, ' ', dpfunc:quoesc(@name), $eol)"/>
          </xsl:otherwise>
      </xsl:choose>

  </xsl:template>

  <xsl:template mode="DefaultProperty" match="*">
    <!-- objAlias: external menu name to be invoked (optional) -->
    <xsl:param name="objAlias" select="''"/>
    <!-- objName: name of object definition in schema (required) -->
    <xsl:param name="objName" select="''"/>
    <!-- pObjName: name of instantiated object (optional) - required for external menu -->
    <xsl:param name="pObjName" select="''"/>
    <!-- pName: property name (required) -->
    <xsl:param name="pName" select="''"/>
    <!-- pValue: property value (required) -->
    <xsl:param name="pValue" select="''"/>
    <!-- Indent: parameter indent (optional, default ' ') -->
    <xsl:param name="Indent" select="' '"/>
    <!-- Inline: parameter separator (optional, default CR) -->
    <xsl:param name="Inline" select="$eol"/>
    <!-- pProp: property node (optional) - required for bitmap -->
    <xsl:param name="pProp" select="''"/>
    <!-- pNode: property node (optional) - required for complex type submode -->
    <xsl:param name="pNode" select="$config-objects-index/self::object[@name=$objName]/ancestor-or-self::*/properties/property[@name=$pName]"/>
    <xsl:param name="forceDefault" select="true()"/>

    <xsl:choose>
        <!-- skip empty node (not supported for product) -->
        <xsl:when test="not($pNode)"/>

        <!-- skip read-only properties -->
        <xsl:when test="($pNode/@read-only='true')"/>

        <!-- skip internal properties -->
        <xsl:when test="($pNode/@internal='true')"/>

        <!-- skip unpersisted properties in save config mode -->
        <xsl:when test="($pNode/@persisted='false')
                         and not($delta-config)"/>

        <!-- skip if there's no value and no node, unless the property allows forced null values -->
        <xsl:when test="(string($pValue)='')
                         and (string($pProp)='')
                         and not($pNode/@force-null='true')"/>

        <!-- skip all default values except for vector properties and admin state -->
        <xsl:when test="($pNode/default=$pValue)
                         and not($pNode/@vector='true')
                         and not($pNode/@name='mAdminState')
                         and not($forceDefault)"/>

        <!-- skip all default admin states except for singletons and intrinsics -->
        <xsl:when test="($pNode/@name='mAdminState')
                         and ($pNode/default=$pValue)
                         and not($config-objects-index/self::object[@name=$objName]/@singleton='true')
                         and not($config-objects-index/self::object[@name=$objName]/@domain-singleton='true')
                         and not($config-objects-index/self::object[@name=$objName]/@intrinsic='true')"/>

        <!-- skip default admin-state for ethernet interfaces -->
        <xsl:when test="($pNode/@name='mAdminState')
                         and ($pNode/default=$pValue)
                         and ($objName = 'EthernetInterface')"/>

        <!-- skip if it's got the special name "empty_*" (webgui form artifact) -->
        <xsl:when test="(starts-with($pName, 'empty_'))"/>

        <!-- value differs from default value -->
        <xsl:otherwise>
            <!-- if sub menu -->
            <xsl:if test="($objAlias!='')">
                <!-- enter menu -->
                <xsl:value-of select="concat($eol, $objAlias, ' ', $pObjName, $eol, '  ')"/>
            </xsl:if>

            <xsl:choose>
                <!-- test if cli alias is defined-->
                <xsl:when test="($pNode/cli-alias)">
                    <!-- set cli alias -->
                    <xsl:variable name="alias" select="$pNode/cli-alias"/>

                    <xsl:choose>
                        <!-- if it is a toggle -->
                        <xsl:when test="($pNode/@type='dmToggle')">
                            <xsl:choose>
                                <!-- if inline parameter or external submenu-->
                                <xsl:when test="($Inline='') or ($objAlias!='')">
                                    <!-- output in form '<alias> <value> [CR]' -->
                                    <xsl:value-of select="concat($Indent, $alias, ' ', dpfunc:esc($pValue), $Inline)"/>
                                </xsl:when>

                                <!-- if single command line -->
                                <xsl:otherwise>
                                    <xsl:choose>
                                        <!-- if toggle is off -->
                                        <xsl:when test="($pValue='off')">
                                            <!-- output in form 'no <alias> [objname]' -->
                                            <xsl:value-of select="concat($Indent, 'no ', $alias, ' ', $pObjName, $eol)"/>
                                        </xsl:when>
                                        <!-- if toggle is on -->
                                        <xsl:otherwise>
                                            <!-- output in form '<alias> [objname]' -->
                                            <xsl:value-of select="concat($Indent, $alias, ' ', $pObjName, $eol)"/>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>

                        <!-- if it is a string values -->
                        <xsl:when test="($pNode/@type='dmString' or $pNode/@type='dmURL' or $pNode/@type='dmXPathExpr' or $pNode/@type='dmTimeStamp')">
                            <!-- string values are in quotes -->
                            <xsl:value-of select="concat($Indent, $alias, ' ', dpfunc:quoesc($pValue), $Inline)"/>
                        </xsl:when>

                        <!-- for everything else, test base node -->
                        <xsl:otherwise>
                            <xsl:variable name="typeNode">
                                <xsl:call-template name="schema-find-type">
                                    <xsl:with-param name="typeName" select="$pNode/@type"/>
                                </xsl:call-template>
                            </xsl:variable>

                            <xsl:choose>
                                <!-- if it is a complex property -->
                                <xsl:when test="($typeNode/*[@base='complex'])">
                                    <xsl:variable name="current" select="." />
                                    <xsl:variable name="submode" select="not($typeNode/type/properties/property[not(cli-alias)])" />

                                    <xsl:value-of select="concat($Indent, $alias)"/>
                                    <xsl:choose>
                                        <!--
                                            cli complex submode was added in 3.7.1, It has been enabled for all products
                                            since 7.1.0.0 since downgrade compatibility is reasonably assured.
                                        -->
                                        <xsl:when test="$submode">
                                            <xsl:value-of select="concat($eol)"/>

                                            <!-- for each complex type property -->
                                            <xsl:for-each select="$typeNode/type/properties/property">
                                                <xsl:variable name="arg-node" select="$current/*[local-name() = current()/@name]" />
                                                <xsl:apply-templates mode="DefaultProperty" select="$arg-node">
                                                    <xsl:with-param name="objName" select="$objName"/>
                                                    <xsl:with-param name="pName" select="@name"/>
                                                    <xsl:with-param name="pValue" select="$arg-node"/>
                                                    <xsl:with-param name="pProp" select="$arg-node"/>
                                                    <xsl:with-param name="Indent" select="concat($Indent, '  ')"/>
                                                    <xsl:with-param name="pNode" select="."/>
                                                </xsl:apply-templates>
                                            </xsl:for-each>

                                            <xsl:value-of select="concat($Indent, 'exit', $eol)"/>
                                        </xsl:when>

                                        <xsl:otherwise>
                                            <!-- for each complex type property -->
                                            <xsl:for-each select="$typeNode/type/properties/property">
                                                <!-- find the drmgmt definition of this property to determine its type. -->
                                                <xsl:variable name="subPropName" select="@name"/>
                                                <xsl:variable name="subPropType" select="$type-index/self::type[@name = current()/@type]" />

                                                <xsl:variable name="arg-node" select="$current/*[local-name() = current()/@name]" />

                                                <xsl:choose>
                                                    <xsl:when test="string($subPropType/@base) = 'bitmap'">
                                                        <xsl:value-of select='concat(" ", dpfunc:quoesc(dpfunc:bitmap-to-string($arg-node)))' />
                                                    </xsl:when>
                                                    <xsl:when test="string($subPropType/@base) = 'enumeration' and string($arg-node) = ''">
                                                        <!-- hidden complex enumerations with no value specified can't be submitted as "" -->
                                                        <xsl:choose>
                                                            <!-- default value specified -->
                                                            <xsl:when test="$subPropType/value-list/value[@default]">
                                                                <xsl:value-of select='concat(" ", dpfunc:quoesc($subPropType/value-list/value[@default]/@name))'/>
                                                            </xsl:when>
                                                            <!-- otherwise (i.e. explicit), set to first element -->
                                                            <xsl:otherwise>
                                                                <xsl:value-of select='concat(" ", dpfunc:quoesc($subPropType/value-list/value[1]/@name))'/>
                                                            </xsl:otherwise>
                                                        </xsl:choose>
                                                    </xsl:when>
                                                    <xsl:when test="string($arg-node) = '' and string(default) != ''">
                                                        <!-- hidden complex toggles with no value specified can't be submitted as "" -->
                                                        <xsl:value-of select='concat(" ", dpfunc:quoesc(default))'/>
                                                    </xsl:when>
                                                    <xsl:otherwise>
                                                        <xsl:value-of select='concat(" ", dpfunc:quoesc($arg-node))'/>
                                                    </xsl:otherwise>
                                                </xsl:choose>
                                            </xsl:for-each>

                                            <xsl:value-of select="$eol"/>
                                        </xsl:otherwise>
                                    </xsl:choose>

                                </xsl:when>

                                <!-- if it is a bitmap -->
                                <xsl:when test="($typeNode/*[@base='bitmap'])">
                                    <xsl:value-of select="concat($Indent, $alias, ' ')"/>
                                    <xsl:value-of select="concat(dpfunc:quoesc(dpfunc:bitmap-to-string(.)), ' ')"/>
                                    <xsl:value-of select="concat($Inline)"/>
                                </xsl:when>

                                <xsl:otherwise>
                                    <!-- write cli output if not empty value -->
                                    <xsl:if test="not(string($pValue)='')">
                                        <xsl:value-of select="concat($Indent, $alias, ' ', dpfunc:esc($pValue), $Inline)"/>
                                    </xsl:if>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:when test="($pNode/@hidden='true')">
                    <!-- Skip hidden properies without cli-alias -->
                </xsl:when>
                <!-- no cli-alias defined -->
                <xsl:otherwise>
                    <xsl:message dpe:type="mgmt" dpe:priority="error" dpe:id="{$DPLOG_WEBGUI_MISSING_CLI_ALIAS}">
                        <dpe:with-param value="{$objName}"/>
                        <dpe:with-param value="{$pName}"/>
                    </xsl:message>
                    <xsl:value-of select="concat('# ', $Indent, $pName, ' ', dpfunc:esc($pValue))"/>
                </xsl:otherwise>
            </xsl:choose>

            <!-- if sub menu -->
            <xsl:if test="($objAlias!='')">
                <!-- exit menu -->
                <xsl:value-of select="concat('exit', $eol)"/>
            </xsl:if>
        </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- convert a null string to "" -->
  <xsl:template match="*" mode="NullableValue">
      <xsl:choose>
          <xsl:when test="string-length()=0">
            <xsl:value-of select="concat($quote, $quote)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="dpfunc:quoesc(text())"/>
          </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

  <!-- ### Actions ######################################################### -->

  <xsl:template match="args[action='FlushDocumentCache']" mode="cli-actions">
    <xsl:choose>
      <xsl:when test="string(MatchPattern)">
          <xsl:value-of select="concat(
                                 'configure terminal', $eol,
                                 'documentcache ', dpfunc:quoesc(XMLManager), $eol,
                                 'clear ', dpfunc:quoesc(MatchPattern), $eol,
                                 'exit', $eol)"/>
      </xsl:when>
      <xsl:otherwise>
          <xsl:value-of select="concat(
                                 'configure terminal', $eol,
                                 'documentcache ', dpfunc:quoesc(XMLManager), $eol,
                                 'clear *', $eol,
                                 'exit', $eol)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="args[action='RefreshDocument']" mode="cli-actions">
      <!-- Turn url supplied via RefreshDocument into a pattern for clear command.  bug32452 -->
      <xsl:variable name="escapedURL" select="regexp:replace(Document,'([?*\]\[.^$])','g','\$1')"/>
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'documentcache ', dpfunc:quoesc(XMLManager), $eol,
                            'clear ',  dpfunc:quoesc($escapedURL), $eol,
                            'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='CacheWSDL']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'no stylesheet ', dpfunc:quoesc(XMLManager), ' ', dpfunc:quoesc(URL), $eol,
                            'cache wsdl ', dpfunc:quoesc(XMLManager), ' ', dpfunc:quoesc(URL), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='Quiesce']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'interface ', dpfunc:quoesc(Interface), $eol,
                            'quiesce', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='Unquiesce']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'interface ', dpfunc:quoesc(Interface), $eol,
                            'no quiesce', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='PacketCapture']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'packet-capture-advanced ', dpfunc:quoesc(Interface), ' temporary:///capture.pcap 30 10000 -1', $eol,
                            'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='StopPacketCapture']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'no packet-capture-advanced ', dpfunc:quoesc(Interface), ' temporary:///capture.pcap', $eol,
                            'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='VLANPacketCapture']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'packet-capture-advanced ', dpfunc:quoesc(concat('vlan:', Interface)), ' temporary:///capture.pcap 30 10000 -1', $eol,
                            'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='VLANStopPacketCapture']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'no packet-capture-advanced ', dpfunc:quoesc(concat('vlan:', Interface)), ' temporary:///capture.pcap', $eol,
                            'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='LinkAggregationPacketCapture']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'packet-capture-advanced ', dpfunc:quoesc(concat('agg:', Interface)), ' temporary:///capture.pcap 30 10000 -1', $eol,
                            'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='LinkAggregationStopPacketCapture']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'no packet-capture-advanced ', dpfunc:quoesc(concat('agg:', Interface)), ' temporary:///capture.pcap', $eol,
                            'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='StandalonePacketCapture']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'packet-capture-advanced ', dpfunc:quoesc(Interface), ' temporary:///capture.pcap 30 10000 -1', $eol,
                            'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='StandaloneStopPacketCapture']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'no packet-capture-advanced ', dpfunc:quoesc(Interface), ' temporary:///capture.pcap', $eol,
                            'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='PacketCaptureDebug']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'packet-capture-advanced ', dpfunc:quoesc(Interface), ' temporary:///capture.pcap ')"/>
      <xsl:choose>
          <xsl:when test="CaptureMode = 'continuous'">
              <xsl:text>-1</xsl:text>
          </xsl:when>
          <xsl:otherwise>
              <xsl:value-of select="dpfunc:quoesc(MaxTime)"/>
          </xsl:otherwise>
      </xsl:choose>
      <xsl:value-of select="concat(' ', dpfunc:quoesc(MaxSize),
                                   ' ', dpfunc:quoesc(Filter), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='UniversalPacketCaptureDebug']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'packet-capture-advanced ')"/>
      <xsl:choose>
          <xsl:when test="InterfaceType = 'Loopback'">
              <xsl:text>lo</xsl:text>
          </xsl:when>
          <xsl:when test="InterfaceType = 'VLAN'">
              <xsl:value-of select="dpfunc:quoesc(concat('vlan:', VLANInterface))"/>
          </xsl:when>
          <xsl:when test="InterfaceType = 'Aggregate'">
              <xsl:value-of select="dpfunc:quoesc(concat('agg:', LinkAggregation))"/>
          </xsl:when>
          <xsl:when test="InterfaceType = 'Ethernet'">
              <xsl:value-of select="dpfunc:quoesc(EthernetInterface)"/>
          </xsl:when>
          <xsl:when test="InterfaceType = 'Standalone'">
              <xsl:value-of select="dpfunc:quoesc(StandaloneInterface)"/>
          </xsl:when>
          <xsl:otherwise>
              <xsl:text>all</xsl:text>
          </xsl:otherwise>
      </xsl:choose>
      
      <xsl:text> temporary:///capture.pcap </xsl:text>
      
      <xsl:choose>
          <xsl:when test="CaptureMode = 'continuous'">
              <xsl:text>-1</xsl:text>
          </xsl:when>
          <xsl:otherwise>
              <xsl:value-of select="dpfunc:quoesc(MaxTime)"/>
          </xsl:otherwise>
      </xsl:choose>

      <xsl:value-of select="concat(' ', dpfunc:quoesc(MaxSize), ' ', dpfunc:quoesc(MaxPacketSize), ' ', 
                                   dpfunc:quoesc(Filter), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='UniversalStopPacketCapture']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'no packet-capture-advanced ')"/>
      <xsl:choose>
          <xsl:when test="InterfaceType = 'Loopback'">
              <xsl:text>lo</xsl:text>
          </xsl:when>
          <xsl:when test="InterfaceType = 'VLAN'">
              <xsl:value-of select="dpfunc:quoesc(concat('vlan:',VLANInterface))"/>
          </xsl:when>
          <xsl:when test="InterfaceType = 'Aggregate'">
              <xsl:value-of select="dpfunc:quoesc(concat('agg:', LinkAggregation))"/>
          </xsl:when>
          <xsl:when test="InterfaceType = 'Ethernet'">
              <xsl:value-of select="dpfunc:quoesc(EthernetInterface)"/>
          </xsl:when>
          <xsl:when test="InterfaceType = 'Standalone'">
              <xsl:value-of select="dpfunc:quoesc(StandaloneInterface)"/>
          </xsl:when>
          <xsl:otherwise>
              <xsl:text>all</xsl:text>
          </xsl:otherwise>
      </xsl:choose>
      
      <xsl:value-of select="concat(' temporary:///capture.pcap', $eol )"/>
  </xsl:template>

  <xsl:template match="args[action='ConvertKey']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'crypto', $eol,
                            'convert-key ',
                            dpfunc:quoesc(ObjectName), ' ',
                            dpfunc:quoesc(OutputFilename), ' ',
                            dpfunc:quoesc(Format), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='ConvertCertificate']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'crypto', $eol,
                            'convert-certificate ',
                            dpfunc:quoesc(ObjectName), ' ',
                            dpfunc:quoesc(OutputFilename), ' ',
                            dpfunc:quoesc(Format), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='CreateLunaClientCert']" mode="cli-actions">
      <xsl:variable name="pNode" select="$schema/action-objects/action[@name='CreateLunaClientCert']"/>

      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'crypto', $eol,
                            'create-luna-clientcert')"/>

      <xsl:apply-templates mode="keygen-param" select="*[local-name()=$pNode//parameter/@name]">
          <xsl:sort select="position()" data-type="number" order="ascending"/>
          <xsl:with-param name="typeNode" select="$pNode"/>
      </xsl:apply-templates>

      <xsl:value-of select="$eol"/>

  </xsl:template>
  <xsl:template match="args[action='ImportLunaClientCert']" mode="cli-actions">
      <xsl:variable name="pNode" select="$schema/action-objects/action[@name='ImportLunaClientCert']"/>

      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'crypto', $eol,
                            'import-luna-clientcert')"/>

      <xsl:apply-templates mode="keygen-param" select="*[local-name()=$pNode//parameter/@name]">
          <xsl:sort select="position()" data-type="number" order="ascending"/>
          <xsl:with-param name="typeNode" select="$pNode"/>
      </xsl:apply-templates>

      <xsl:value-of select="$eol"/>

  </xsl:template>


  <xsl:template match="args[action='KerberosTicketDelete']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'crypto', $eol,
                            'kerberos-ticket-delete ',
                            dpfunc:quoesc(Realm), ' ',
                            dpfunc:quoesc(Owner), ' ',
                            dpfunc:quoesc(Client), ' ',
                            dpfunc:quoesc(Server), $eol)"/>
  </xsl:template>
  
  <xsl:template match="args[action='AddPasswordMap']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'crypto', $eol,
                            'add password-map ', 
							dpfunc:quoesc(AliasName), ' ', 
							dpfunc:quoesc(Password), $eol)"/>
  </xsl:template>
  
  <xsl:template match="args[action='NoPasswordMap']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'crypto', $eol,
                            'no password-map', $eol, 
                            'y', $eol)"/>
  </xsl:template>
  <xsl:template match="args[action='DeletePasswordMap']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'crypto', $eol,
                            'delete password-map ', 
							dpfunc:quoesc(AliasName), $eol)"/>
  </xsl:template>
  
  <xsl:template match="args[action='OAuthCacheDelete']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'crypto', $eol,
                            'oauth-cache-delete ',
                            dpfunc:quoesc(ClientId), ' ',
                            dpfunc:quoesc(CacheType), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='DeleteHSMKey']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'crypto', $eol,
                            'hsm-delete-key ', dpfunc:quoesc(KeyHandle), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='AddKnownHost']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol, 
                            'client-known-host ',
                            dpfunc:quoesc(Host), ' ',
                            dpfunc:quoesc(Type), ' ',
                            dpfunc:quoesc(Key), ' ',
                            dpfunc:quoesc(ClientName), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='DeleteKnownHost']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol, 
                            'no client-known-host ',
                            dpfunc:quoesc(Host), ' ',
                            dpfunc:quoesc(ClientName), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='CryptoImport']" mode="cli-actions">
      <xsl:variable name="passwdArgs">
        <xsl:choose>
          <xsl:when test="string(ImportPassword)">
            <xsl:value-of select="concat('password ', dpfunc:quoesc(ImportPassword), ' ')"/>
          </xsl:when>
          <xsl:when test="string(ImportPasswordAlias)">
            <xsl:value-of select="concat('password-alias ', dpfunc:quoesc(ImportPasswordAlias), ' ')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="''"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:value-of select="concat('configure terminal', $eol,
                                   'crypto', $eol,
                                   'crypto-import ',
                                   dpfunc:quoesc(ObjectType), ' ', dpfunc:quoesc(ObjectName), ' ',
                                   'input ', dpfunc:quoesc(InputFilename), ' ',
                                   $passwdArgs, $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='CryptoExport']" mode="cli-actions">
      <xsl:variable name="mechanismargs">
        <xsl:choose>
          <xsl:when test="string(Mechanism) and ObjectType='key'">
            <xsl:value-of select="concat('mechanism ', dpfunc:quoesc(Mechanism), ' ')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="''"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:value-of select="concat('configure terminal', $eol,
                                   'crypto', $eol,
                                   'crypto-export ',
                                   dpfunc:quoesc(ObjectType), ' ', dpfunc:quoesc(ObjectName), ' ',
                                   'output ', dpfunc:quoesc(concat('temporary:///', OutputFilename)), ' ',
                                   $mechanismargs, $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='HSMCloneKWK']" mode="cli-actions">
      <xsl:variable name="inputargs">
        <xsl:choose>
          <xsl:when test="string(InputFilename)">
            <xsl:value-of select="concat('input ', dpfunc:quoesc(InputFilename), ' ')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="''"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="outputargs">
        <xsl:choose>
          <xsl:when test="string(OutputFilename)">
            <xsl:value-of select="concat('output ', dpfunc:quoesc(concat('temporary:///', OutputFilename)), ' ')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="''"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:value-of select="concat('configure terminal', $eol,
                                   'crypto', $eol,
                                   'hsm-clone-kwk ',
                                   $inputargs,
                                   $outputargs,
                                   $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='HSMSetRole']" mode="cli-actions">
      <xsl:value-of select="concat('configure terminal', $eol,
                                   'crypto', $eol,
                                   'hsm-set-role ',
                                   dpfunc:quoesc(Role), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='CryptoModeSet']" mode="cli-actions">
      <xsl:value-of select="concat('configure terminal', $eol,
                                   'crypto', $eol,
                                   'crypto-mode-set ',
                                   dpfunc:quoesc(Mode), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='CryptoHwDisable']" mode="cli-actions">
      <xsl:value-of select="concat('configure terminal', $eol,
                                   'crypto', $eol,
                                   'crypto-hw-disable ',
                                   dpfunc:quoesc(Amount), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='ApplyPatch']" mode="cli-actions">
      <!-- this command expects a bare filename here -->
      <xsl:variable name="bare-file">
          <xsl:choose>
              <xsl:when test="starts-with(File, 'image:///')">
                  <xsl:value-of select="substring-after(File, 'image:///')"/>
              </xsl:when>
              <xsl:otherwise>
                  <xsl:value-of select="File"/>
              </xsl:otherwise>
          </xsl:choose>
      </xsl:variable>
      <xsl:variable name="accept-license">
          <xsl:choose>
              <xsl:when test="AcceptLicense">
                   <xsl:text>accept-license </xsl:text>
              </xsl:when>
              <xsl:otherwise>
                   <xsl:text> </xsl:text>
              </xsl:otherwise>
          </xsl:choose>      
      </xsl:variable>      
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'flash', $eol,
                            'boot image ', $accept-license, dpfunc:quoesc($bare-file), $eol,
                            'exit', $eol, 'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='Reinitialize']" mode="cli-actions">

      <!-- this command expects a bare filename here -->
      <xsl:variable name="bare-file">
          <xsl:choose>
              <xsl:when test="starts-with(File, 'image:///')">
                  <xsl:value-of select="substring-after(File, 'image:///')"/>
              </xsl:when>
              <xsl:otherwise>
                  <xsl:value-of select="File"/>                  
              </xsl:otherwise>
          </xsl:choose>
      </xsl:variable>
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'flash', $eol,
                            'reinitialize ', dpfunc:quoesc($bare-file), $eol,
                            'exit', $eol, 'exit', $eol)"/>
  </xsl:template>

 <xsl:template match="args[action='BootSwitch']" mode="cli-actions">
      <!-- this command expects a bare filename here -->
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'flash', $eol,
                            'boot switch', $eol,
                            'exit', $eol, 'exit', $eol)"/>
  </xsl:template>

<xsl:template match="args[action='BootDelete']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'flash', $eol,
                            'boot delete', $eol,
                            'exit', $eol, 'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='SelectConfig']" mode="cli-actions">
      <!-- this command expects a bare filename here -->
      <xsl:variable name="bare-file">
          <xsl:choose>
              <xsl:when test="starts-with(File, 'config:///')">
                  <xsl:value-of select="substring-after(File, 'config:///')"/>
              </xsl:when>
              <xsl:otherwise>
                  <xsl:value-of select="File"/>
              </xsl:otherwise>
          </xsl:choose>
      </xsl:variable>
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'flash', $eol,
                            'boot config ', dpfunc:quoesc($bare-file), $eol,
                            'exit', $eol, 'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='UndoConfig']" mode="cli-actions">
      <xsl:variable name="type" select="Class"/>
      <xsl:variable name="alias" select="$config-objects-index/self::object[@name=$type]/cli-alias"/>
      <xsl:variable name="uri" select="$config-objects-index/self::object[@name=$type]/uri"/>

      <xsl:value-of select="concat('configure terminal', $eol)"/>
      <!-- bug 32752: must check specifically for SSLProxyProfile to prevent undo error -->
      <xsl:if test="starts-with($uri, 'crypto') and $type != 'SSLProxyProfile'">
          <xsl:value-of select="concat('crypto', $eol)"/>
      </xsl:if>
      <xsl:value-of select="concat('undo ', dpfunc:quoesc($alias), ' ', dpfunc:quoesc(Name), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='FetchFile']" mode="cli-actions">
      <xsl:value-of select="concat('configure terminal', $eol, 'copy ')"/>
      <xsl:if test="Overwrite = 'on'">
          <xsl:text>-f</xsl:text>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="XMLManager">
          <xsl:value-of select="concat(' ', dpfunc:quoesc(URL), ' ', dpfunc:quoesc(File), ' ', dpfunc:quoesc(XMLManager), $eol)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat(' ', dpfunc:quoesc(URL), ' ', dpfunc:quoesc(File), $eol)"/>
        </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

  <xsl:template match="args[action='MoveFile']" mode="cli-actions">
      <xsl:value-of select="concat('configure terminal', $eol, 'move ')"/>
      <xsl:if test="Overwrite = 'on'">
          <xsl:text>-f</xsl:text>
      </xsl:if>
      <xsl:value-of select="concat(' ', dpfunc:quoesc(sURL), ' ', dpfunc:quoesc(dURL), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='Shutdown']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'flash', $eol,
                            'shutdown ', dpfunc:quoesc(Mode))"/>
      <xsl:if test="Delay">
          <xsl:value-of select="concat(' ', dpfunc:quoesc(Delay))"/>
      </xsl:if>
      <xsl:value-of select="concat($eol, 'exit', $eol, 'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='CreateTAMFiles']" mode="cli-actions">
      <xsl:variable name="actionNode" select="$schema/action-objects/action[@name='CreateTAMFiles']"/>
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'create-tam-files ')"/>

      <xsl:apply-templates mode="create-tam-files-params">
          <xsl:with-param name="paramsNode" select="$actionNode/parameters"/>
      </xsl:apply-templates>

      <xsl:value-of select="$eol"/>
  </xsl:template>

  <xsl:template mode="create-tam-files-params" match="*">
      <xsl:param name="paramsNode"/>

     <xsl:variable name="name" select="local-name(.)"/>
     <xsl:variable name="node" select="$paramsNode/parameter[@name=$name]"/>

      <xsl:if test="string(text()) and string($node/cli-alias)">
              <xsl:value-of select="concat(' ', $node/cli-alias, ' ', dpfunc:quoesc(text()))"/>
      </xsl:if>
  </xsl:template>

  <xsl:template match="args[action='Keygen']" mode="cli-actions">
      <xsl:variable name="pNode" select="$schema/action-objects/action[@name='Keygen']"/>

      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'crypto', $eol,
                            'keygen')"/>

      <xsl:variable name="order">
          <xsl:choose>
              <xsl:when test="LDAPOrder='on'">
                  <xsl:value-of select="'descending'"/>
              </xsl:when>
              <xsl:otherwise>
                  <xsl:value-of select="'ascending'"/>
              </xsl:otherwise>
          </xsl:choose>
      </xsl:variable>

      <xsl:apply-templates mode="keygen-param" select="*[local-name()=$pNode//parameter/@name]">
          <xsl:sort select="position()" data-type="number" order="{$order}"/>
          <xsl:with-param name="typeNode" select="$pNode"/>
      </xsl:apply-templates>

      <xsl:value-of select="$eol"/>
  </xsl:template>

  <xsl:template match="args[action='B2BArchiveNow']" mode="cli-actions">
      <xsl:choose>
        <xsl:when test="ArchiveAllGateways='on'">
          <xsl:value-of select="concat('configure terminal', $eol,
                                'b2bp-archive-purge-now ', dpfunc:quoesc(ArchiveIncomplete), ' ',
                                dpfunc:quoesc(ArchiveAllGateways))"/>
          <xsl:if test="string(ArchiveUnexpiredEBMS)">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(ArchiveUnexpiredEBMS))"/>
          </xsl:if>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat(
                                'configure terminal', $eol,
                                'b2bp-archive-purge-now ', dpfunc:quoesc(ArchiveIncomplete))"/>
          <xsl:if test="string(ArchiveAllGateways)">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(ArchiveAllGateways))"/>
          </xsl:if>
          <xsl:value-of select="concat(' ', dpfunc:quoesc(B2BGatewayName))"/>
          <xsl:if test="string(ArchiveUnexpiredEBMS)">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(ArchiveUnexpiredEBMS))"/>
          </xsl:if>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:value-of select="$eol"/>
  </xsl:template>

  <!-- suppress directional parameter -->
  <xsl:template mode="keygen-param" match="LDAPOrder"/>

  <!-- express command line parameter -->
  <xsl:template mode="keygen-param" match="*">
      <xsl:param name="typeNode"/>

      <xsl:variable name="paramName" select="local-name(.)"/>
      <xsl:variable name="paramNode" select="$typeNode//parameter[@name=$paramName]"/>

      <xsl:choose>
          <xsl:when test="($paramNode/@type='dmToggle') and (text()='off')"/>
          <xsl:when test="($paramNode/@type='dmToggle') and (text()='on')">
              <xsl:value-of select="concat(' ', $paramNode/cli-alias)"/>
          </xsl:when>
          <xsl:when test="text() and not(text()='')">
              <xsl:value-of select="concat(' ', $paramNode/cli-alias, ' ', dpfunc:quoesc(text()))"/>
          </xsl:when>
      </xsl:choose>
  </xsl:template>

  <xsl:template match="args[action='SetTimeAndDate']" mode="cli-actions">
      <xsl:if test="(Date != '')">
          <xsl:value-of select="concat($eol, 'clock ', dpfunc:quoesc(Date), $eol)"/>
      </xsl:if>
      <xsl:if test="(Time != '')">
          <xsl:value-of select="concat('clock ', dpfunc:quoesc(Time), $eol)"/>
      </xsl:if>

  </xsl:template>

  <xsl:template match="args[action='Disconnect']" mode="cli-actions">
      <xsl:value-of select="concat( 'configure terminal', $eol,
                                    'disconnect ', dpfunc:quoesc(id), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='Ping']" mode="cli-actions">
      <xsl:variable name="pingCmd">
          <xsl:if test="string(useIPv) != '' and string(useIPv) != 'default'">
              <xsl:value-of select="concat(' ', dpfunc:quoesc(string(useIPv)))"/>
          </xsl:if>
          <xsl:value-of select="concat(' ', dpfunc:quoesc(string(RemoteHost)))"/>
      </xsl:variable>
      <xsl:value-of select="concat('ping', $pingCmd, $eol)" />
  </xsl:template>
  
  <!--  seems like cli-error-processing templates are not being used. -->
  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='Ping']">
      <response>
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                  <xsl:choose>
                      <xsl:when test="starts-with(script-log/log//log-entry/message, 'Packets dropped')">
                          <result>ERROR</result>
                          <details>
                              <xsl:text>Ping packets dropped to remote host "</xsl:text>
                              <xsl:value-of select="../args/RemoteHost"/>
                              <xsl:text>". Please check system log or use
                              the CLI command for more details.</xsl:text>
                          </details>
                      </xsl:when>
                      <xsl:when test="starts-with(script-log/log//log-entry/message, 'Failed to resolve')">
                          <result>ERROR</result>
                          <details>
                              <xsl:text>Ping failed to resolve remote host "</xsl:text>
                              <xsl:value-of select="../args/RemoteHost"/>
                              <xsl:text>". Please check system log or use
                              the CLI command for more details.</xsl:text>
                          </details>
                      </xsl:when>
                      <xsl:when test="starts-with(script-log/log//log-entry/message, 'Host unreachable')">
                          <result>ERROR</result>
                          <details>
                              <xsl:text>Ping failed unreachable remote host "</xsl:text>
                              <xsl:value-of select="../args/RemoteHost"/>
                              <xsl:text>". Please check system log or use
                              the CLI command for more details.</xsl:text>
                          </details>
                      </xsl:when>
                      <xsl:otherwise>
                          <result>ERROR</result>
                          <details>
                              <xsl:text>Could not ping remote host "</xsl:text>
                              <xsl:value-of select="../args/RemoteHost"/>
                              <xsl:text>". Please check system log.</xsl:text>
                          </details>
                      </xsl:otherwise>
                  </xsl:choose>
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>
                      <xsl:text>Successful ping to remote host "</xsl:text>
                      <xsl:value-of select="../args/RemoteHost"/>
                      <xsl:text>".</xsl:text>
                  </details>
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>

  <xsl:template match="args[action='TCPConnectionTest']" mode="cli-actions">
      <xsl:variable name="testCmd">
          <xsl:value-of select="concat(' ', dpfunc:quoesc(string(RemoteHost)))"/>
          <xsl:value-of select="concat(' ', dpfunc:quoesc(string(RemotePort)))"/>
          <xsl:if test="string(useIPv) != '' and string(useIPv) != 'default'">
              <xsl:value-of select="concat(' ', dpfunc:quoesc(string(useIPv)))"/>
          </xsl:if>
      </xsl:variable>
      <xsl:value-of select="concat('test tcp-connection', $testCmd, $eol)" />
  </xsl:template>

  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='TCPConnectionTest']">
      <response>
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                  <result>ERROR</result>
                  <xsl:choose>
                      <xsl:when test="contains(script-log/log//log-entry/message, 'connection refused')">
                          <details>
                              <xsl:text>TCP connection failed (connection refused)</xsl:text>
                          </details>
                      </xsl:when>
                      <xsl:when test="contains(script-log/log//log-entry/message, 'dns lookup failed')">
                          <details>
                              <xsl:text>TCP connection failed (dns lookup failed)</xsl:text>
                          </details>
                      </xsl:when>
                      <xsl:when test="contains(script-log/log//log-entry/message, 'connection timeout')">
                          <details>
                              <xsl:text>TCP connection failed (connection timeout)</xsl:text>
                          </details>
                      </xsl:when>
                      <xsl:otherwise>
                          <details>
                              <xsl:text>TCP connection failed</xsl:text>
                          </details>
                      </xsl:otherwise>
                  </xsl:choose>
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>
                      <xsl:text>TCP connection successful</xsl:text>
                  </details>
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>

  <xsl:template match="args[action='ChangePassword']" mode="cli-actions">
     <xsl:value-of select="concat('configure terminal', $eol,
                            'user-password ', dpfunc:quoesc(Password), ' ', dpfunc:quoesc(OldPassword), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='SetRBMDebugLog']" mode="cli-actions">
      <xsl:value-of select="concat('configure terminal', $eol)"/>

      <xsl:variable name="log-config">
        <xsl:call-template name="do-mgmt-request">
            <xsl:with-param name="session">
                <xsl:choose>
                    <xsl:when test="../args/session"><xsl:value-of select="../args/session"/></xsl:when>
                    <xsl:otherwise><xsl:value-of select="$sessionid"/></xsl:otherwise>
                </xsl:choose>
            </xsl:with-param>
            <xsl:with-param name="request">
                <request>
                  <operation type="get-config">
                    <request-class>LogTarget</request-class>
                    <request-name>default-log</request-name>
                  </operation>
                </request>
            </xsl:with-param>
        </xsl:call-template>
      </xsl:variable>

      <xsl:choose>
          <xsl:when test="string(RBMLog) = 'on'">
              <xsl:value-of select="concat('set-system-var var://system/map/debug 3', $eol)"/>
              <xsl:value-of select="concat('logging event default-log rbm debug', $eol)"/>
          </xsl:when>

          <xsl:otherwise>
              <xsl:value-of select="concat('set-system-var var://system/map/debug 0', $eol)"/>
              <xsl:if test="$log-config/response/operation[@type='get-config']
                            /configuration/*[(local-name()='LogTarget') and (@name='default-log')]
                            /LogEvents[Class='rbm']">
                  <xsl:value-of select="concat('no logging event default-log rbm', $eol)"/>
              </xsl:if>
          </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

  <xsl:template match="args[action='SetLogLevel']" mode="cli-actions">
      <xsl:value-of select="concat('configure terminal', $eol,
                                   'loglevel ', dpfunc:quoesc(LogLevel), $eol)"/>

              <xsl:variable name="log-config">
                <xsl:call-template name="do-mgmt-request">
                    <xsl:with-param name="session">
                        <xsl:choose>
                    <xsl:when test="../args/session"><xsl:value-of select="../args/session"/></xsl:when>
                    <xsl:otherwise><xsl:value-of select="$sessionid"/></xsl:otherwise>
                        </xsl:choose>
                    </xsl:with-param>
                    <xsl:with-param name="request">
                        <request>
                          <operation type="get-config">
                            <request-class>LogTarget</request-class>
                            <request-name>default-log</request-name>
                          </operation>
                        </request>
                    </xsl:with-param>
                </xsl:call-template>
              </xsl:variable>

      <xsl:if test="InternalLog">
          <xsl:choose>
              <xsl:when test="string(InternalLog) = 'on'">
                  <xsl:value-of select="concat('logging event default-log webgui ', dpfunc:quoesc(LogLevel), $eol)"/>
              </xsl:when>

              <xsl:otherwise>
              <xsl:if test="$log-config/response/operation[@type='get-config']
                              /configuration/*[(local-name()='LogTarget') and (@name='default-log')]
                              /LogEvents[Class='webgui']">
                  <xsl:value-of select="concat('no logging event default-log webgui', $eol)"/>
              </xsl:if>
          </xsl:otherwise>
      </xsl:choose>
      </xsl:if>

      <xsl:if test="RBMLog">
          <xsl:choose>
              <xsl:when test="string(RBMLog) = 'on'">
                  <xsl:value-of select="concat('set-system-var var://system/map/debug 3', $eol)"/>
                  <xsl:value-of select="concat('logging event default-log rbm debug', $eol)"/>
              </xsl:when>

              <xsl:otherwise>
                  <xsl:value-of select="concat('set-system-var var://system/map/debug 0', $eol)"/>
                  <xsl:if test="$log-config/response/operation[@type='get-config']
                                /configuration/*[(local-name()='LogTarget') and (@name='default-log')]
                                /LogEvents[Class='rbm']">
                      <xsl:value-of select="concat('no logging event default-log rbm', $eol)"/>
                  </xsl:if>
              </xsl:otherwise>
          </xsl:choose>
      </xsl:if>
      <xsl:if test="GlobalIPLogFilter">
          <xsl:choose>
              <xsl:when test="string(GlobalIPLogFilter) != ''">
                    <xsl:value-of select="concat('globallogipfilter ', dpfunc:quoesc(GlobalIPLogFilter), $eol)"/>
              </xsl:when>

              <xsl:otherwise>
                    <xsl:value-of select="concat('no globallogipfilter', $eol)"/>
              </xsl:otherwise>
          </xsl:choose>
      </xsl:if>
  </xsl:template>

  <xsl:template match="args[action='ErrorReport']" mode="cli-actions">
      <xsl:value-of select="concat('configure terminal', $eol)"/>
      <xsl:if test="string(InternalState) = 'on'">
          <xsl:value-of select="concat('save internal-state', $eol)"/>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="string(RedirectToTemporary) = 'on'">
          <xsl:value-of select="concat('save error-report on', $eol)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat('save error-report', $eol)"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:if test="string(InternalState) = 'on'">
          <xsl:value-of select="concat('delete temporary:///internal-state.txt', $eol)"/>
      </xsl:if>
  </xsl:template>

  <xsl:template match="args[action='SendErrorReport']" mode="cli-actions">
    <xsl:choose>
      <xsl:when test="EmailSenderAddress != ''">
        <xsl:value-of select="concat('configure terminal', $eol, 
                                 'send error-report', 
                                 ' ', dpfunc:quoesc(SmtpServer),
                                 ' ', dpfunc:quoesc(LocationIdentifier),
                                 ' ', dpfunc:quoesc(EmailAddress), 
                                 ' ', dpfunc:quoesc(EmailSenderAddress), $eol)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat('configure terminal', $eol, 
                                 'send error-report', 
                                 ' ', dpfunc:quoesc(SmtpServer),
                                 ' ', dpfunc:quoesc(LocationIdentifier),
                                 ' ', dpfunc:quoesc(EmailAddress), $eol)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="args[action='DeviceCertificate']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'crypto', $eol,
                            'keygen CN ', dpfunc:quoesc(CN), ' rsa 1024 export-sscert file-name device-id ')"/>
      <!-- negative test to catch if the implied default 'on' is changed -->
      <xsl:if test="string(SSCert) != 'off'">
          <xsl:value-of select="concat(
                                'gen-sscert', $eol,
                                'key device-id cert:///device-id-privkey.pem', $eol,
                                'certificate device-id cert:///device-id-sscert.pem', $eol,
                                'idcred device-id device-id device-id', $eol,
                                'profile device-id device-id', $eol,
                                'exit', $eol,
                                'sslproxy device-id reverse device-id', $eol)"/>
      </xsl:if>
      <xsl:value-of select="$eol"/>
  </xsl:template>

  <!-- LocateDevice Action -->
  <xsl:template match="args[action='LocateDevice']" mode="cli-actions">
      <xsl:choose>
        <xsl:when test="string(LocateLED) != 'off'">
          <xsl:value-of select="concat('configure terminal', $eol,
                                       'locate-device on', $eol)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat('configure terminal', $eol,
                                       'locate-device off', $eol)"/>
        </xsl:otherwise>
      </xsl:choose>
  </xsl:template>
  
  <!-- Wsrr Test Connection Action Custom Message -->
    <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='WsrrValidateServer']">
      <response>
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                <result>ERROR</result>
                  <details>
                    <xsl:value-of select="script-log/log//log-entry/message"/>
                  </details>       
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>
                    <xsl:text>Connection to WSRR server successful.</xsl:text>
                  </details>
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>

    <!-- ************************************************************ -->
    <!-- canonical action templates -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-actions" match="args[action]" priority="-5">
        <xsl:variable name="actName" select="action"/>
        <xsl:variable name="aNode" select="."/>
        <xsl:variable name="pNode" select="$schema/action-objects/action[@name=$actName]"/>

        <xsl:variable name="alias" select="$pNode/cli-alias"/>

        <xsl:value-of select="concat('configure terminal', $eol)"/>
        <xsl:value-of select="$alias"/>

        <xsl:for-each select="$pNode/parameters/parameter">
            <xsl:variable name="pName" select="@name"/>
            <xsl:value-of select="concat(' ', dpfunc:quoesc($aNode/*[local-name()=$pName]))"/>
        </xsl:for-each>

        <xsl:value-of select="$eol"/>
    </xsl:template>

  <xsl:template match="text()" mode="cli-object"/>
  <xsl:template match="text()" mode="cli-delete-object"/>
  <xsl:template match="text()" mode="cli-actions"/>

  <xsl:template match="text()" mode="DNSNameService"/>
  <xsl:template match="text()" mode="EthernetInterface"/>
  <xsl:template match="text()" mode="CRLFetch"/>
  <xsl:template match="text()" mode="CRLFetchConfig"/>
  <xsl:template match="text()" mode="HTTPService"/>
  <xsl:template match="text()" mode="NTPService"/>
  <xsl:template match="text()" mode="TimeSettings"/>
  <xsl:template match="text()" mode="Standby"/>
  <xsl:template match="text()" mode="StylePolicy"/>
  <xsl:template match="text()" mode="HTTPUserAgent"/>
  <xsl:template match="text()" mode="StylesheetRefresh"/>
  <xsl:template match="text()" mode="TCPProxyService"/>
  <xsl:template match="text()" mode="URLMap"/>
  <xsl:template match="text()" mode="URLRefreshPolicy"/>
  <xsl:template match="text()" mode="CompileOptionsPolicy"/>
  <xsl:template match="text()" mode="User"/>
  <xsl:template match="text()" mode="XMLManager"/>
  <xsl:template match="text()" mode="XMLManagerCanonical"/>
  <xsl:template match="text()" mode="ParserLimits"/>
  <xsl:template match="text()" mode="DocumentCache"/>
  <xsl:template match="text()" mode="XSLProxyService"/>
  <xsl:template match="text()" mode="HTTPProxyService"/>
  <xsl:template match="text()" mode="StylePolicyRule"/>
  <xsl:template match="text()" mode="Matching"/>
  <xsl:template match="text()" mode="MessageContentFilters"/>
  <xsl:template match="text()" mode="SystemSettings"/>
  <xsl:template match="text()" mode="SNMPSettings"/>
  <xsl:template match="text()" mode="RADIUSSettings"/>
  <xsl:template match="text()" mode="UserGroup"/>
  <xsl:template match="text()" mode="ShellAlias"/>
  <xsl:template match="text()" mode="XSLCoprocService"/>
  <xsl:template match="text()" mode="TelnetService"/>
  <xsl:template match="text()" mode="LoadBalancerGroup"/>
  <xsl:template match="text()" mode="CryptoSSKey"/>
  <xsl:template match="text()" mode="URLRewritePolicy"/>
  <xsl:template match="text()" mode="SSLProxyProfile"/>
  <xsl:template match="text()" mode="CryptoEngine"/>
  <xsl:template match="text()" mode="CryptoFWCred"/>
  <xsl:template match="text()" mode="AAAPolicy"/>
  <xsl:template match="text()" mode="XMLFirewallService"/>
  <xsl:template match="text()" mode="CryptoKey"/>
  <xsl:template match="text()" mode="CryptoCertificate"/>
  <xsl:template match="text()" mode="CryptoIdentCred"/>
  <xsl:template match="text()" mode="CryptoValCred"/>
  <xsl:template match="text()" mode="CryptoProfile"/>
  <xsl:template match="text()" mode="CryptoKerberosKDC"/>
  <xsl:template match="text()" mode="LogLabel"/>
  <xsl:template match="text()" mode="LogTarget"/>
  <xsl:template match="text()" mode="DefaultLogTarget"/>
  <xsl:template match="text()" mode="MQQM"/>
  <xsl:template match="text()" mode="MQGW"/>
  <xsl:template match="text()" mode="MQhost"/>
  <xsl:template match="text()" mode="MQproxy"/>
  <xsl:template match="text()" mode="SSHService"/>
  <xsl:template match="text()" mode="HTTPUserAgent"/>
  <xsl:template match="text()" mode="Statistics"/>
  <xsl:template match="text()" mode="Throttler"/>
  <xsl:template match="text()" mode="MessageMatching"/>
  <xsl:template match="text()" mode="CountMonitor"/>
  <xsl:template match="text()" mode="DurationMonitor"/>
  <xsl:template match="text()" mode="CanonicalProperty"/>
  <xsl:template match="text()" mode="xmltrace"/>
  <xsl:template match="text()" mode="HTTPInputConversionMap"/>
  <xsl:template match="text()" mode="NetworkSettings"/>
  <xsl:template match="text()" mode="XPathRoutingMap"/>
  <xsl:template match="text()" mode="SchemaExceptionMap"/>
  <xsl:template match="text()" mode="DocumentCryptoMap"/>
  <xsl:template match="text()" mode="ErrorReportSettings"/>
  <xsl:template match="text()" mode="ACLEntry"/>
  <xsl:template match="text()" mode="ImportPackage"/>
  <xsl:template match="text()" mode="Domain"/>
  <xsl:template match="text()" mode="TAM"/>
  <xsl:template match="text()" mode="Netegrity"/>
  <xsl:template match="text()" mode="XMLMgmt"/>
  <xsl:template match="text()" mode="RESTMgmt"/>
  <xsl:template match="text()" mode="WebGUI"/>
  <xsl:template match="text()" mode="RBMSettings"/>
  <xsl:template match="text()" mode="SQLDataSource"/>
  <xsl:template match="text()" mode="HostAlias"/>
  <xsl:template match="text()" mode="XACMLPDP"/>
  <xsl:template match="text()" mode="CookieAttributePolicy"/>
</xsl:stylesheet>
