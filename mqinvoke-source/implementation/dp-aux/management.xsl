<?xml version="1.0" encoding="UTF-8" ?>
<!--
  Licensed Materials - Property of IBM
  IBM WebSphere DataPower Appliances
  Copyright IBM Corporation 2007, 2009. All Rights Reserved.
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
 
 Procedure to add new template:
 
 (1) Use the following template in a preceeding comment to show 
     how to call the template - clearly indicate the template parameter
     elements
 
    <xsl:variable name="example-result">
        <xsl:call-template name="do-mgmt-request">
            <xsl:with-param name="request">
                <request>
                  <operation type="example-operation">
                      <example-parameter/>
                  </operation>
                </request>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:variable>
    
 (2) Add your new template to the file 'datapower/webgui/map.xsl'
 
    Use the following template for your new template. Please clearly structure 
    the template to distinguish between inputs, procesing, and output.
    
    DO NOT ADD TO THIS FILE!!

    Unprotected functions go into map-dmz.xsl and - by default - everything
    else goes into map.xsl.
 
    <xsl:template mode="request" match="operation[@type='example-operation']">
        <xsl:param name="session" select="$sessionid"/>
        
        <xsl:variable name='example-parameter' select="example-parameter"/>
        
        <xsl:variable name='example-result'>
          <xsl:choose>
            <xsl:when test="function-available('dpgui:example-operation')">
              <xsl:copy-of select="dpgui:example-operation($example-parameter)"/>
            </xsl:when>
          </xsl:choose>
        </xsl:variable>
        
        <operation type='{@type}'>
          <xsl:copy-of select="$example-result"/>
        </operation>
    </xsl:template>
  
 (3) The response will be in the form 
     $example-result/response/operation/*
     
-->


<xsl:stylesheet version="1.0" 
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:env="http://www.w3.org/2003/05/soap-envelope"
                xmlns:dpm="http://www.datapower.com/schemas/management"
                xmlns:dp="http://www.datapower.com/extensions"
                xmlns:regexp="http://exslt.org/regular-expressions"
                extension-element-prefixes="dp"
                exclude-result-prefixes="env dp dpm regexp">

  <xsl:output method="xml" encoding="utf-8" indent="yes"/>

  <!-- import inprotected functions -->
  <xsl:include href="map-dmz.xsl"/>

  <!-- sessionid is either 'default' or part of form data -->
  <xsl:variable name="sessionid">
    <xsl:choose>
      <xsl:when test="/request/args/session 
                      and not(/request/args/session='')
                      and not(/request/args/session='0')">
        <xsl:value-of select="/request/args/session"/>
      </xsl:when>
      <xsl:when test="/request/args/arg[@name = 'session']
                      and not(/request/args/arg[@name = 'session']='')
                      and not(/request/args/arg[@name = 'session']='0')">
        <xsl:value-of select="/request/args/arg[@name = 'session']"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="id-cookie-value">
            <xsl:if test="function-available('dp:http-request-header')">
                <xsl:value-of select="string(regexp:match( dp:http-request-header('Cookie'), '(?:^|;)\s*ibmwdp=(.*?)(?:;|$)' )[2])" />
            </xsl:if>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$id-cookie-value != '' and $id-cookie-value != '0'">
                <xsl:value-of select="$id-cookie-value" />
            </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="'default'"/>
      </xsl:otherwise>
    </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- this is for when we're invoked directly -->
  <xsl:template name="mgmt-request" match="/request">
    <xsl:param name="session" select="$sessionid"/>
    
    <xsl:element name="response">    
        <xsl:apply-templates mode="request">
            <xsl:with-param name="session" select="$session"/>
        </xsl:apply-templates>        
    </xsl:element>
  </xsl:template>

  <!-- this is for when we're imported and invoked with call-template -->
  <xsl:template name="do-mgmt-request">
    <xsl:param name="session" select="$sessionid"/>
    <xsl:param name="request"/>
    
    <xsl:element name="response">
      <xsl:for-each select="$request">
        <xsl:apply-templates mode="request">
            <xsl:with-param name="session" select="$session"/>
        </xsl:apply-templates>
      </xsl:for-each>
    </xsl:element>

  </xsl:template>

  <!-- for all operations not listed in map-dmz.xsl, send SOAP request to MAP -->
  <xsl:template mode="request" match="operation">
    <xsl:param name="session" select="$sessionid"/>    
    
    <!-- make soap call to MAP -->
    <xsl:variable name="httpHeaders">
        <header name="X-DataPower-Delta-Config"><xsl:value-of select="boolean(dp:local-variable('delta-config'))" /></header>
    </xsl:variable>

    <xsl:variable name="result">
        <dp:url-open target="http://127.0.0.1:63503" response="responsecode" data-type="xml" http-headers="$httpHeaders" timeout="3600">
            <env:Envelope>
                <env:Body>
                    <dpm:request session-id="{$session}">
                        <xsl:copy-of select="." />
                    </dpm:request>
                </env:Body>
            </env:Envelope>        
        </dp:url-open>
    </xsl:variable>
    
    <xsl:choose>
        <!-- Make sure the Response Code is 200 = 'OK' -->
        <xsl:when test="$result/url-open/responsecode = '200'">
            <xsl:choose>
                <!-- If no response, error has occurred -->
                <xsl:when test="not($result/url-open/response/
                  env:Envelope/env:Body/dpm:response/operation)">
                    <xsl:choose>
                        <!-- Error code 196609 == DPRESULT_PARSER_BADCHAR => File has invalid character.
                             Tell the WebGUI we can't edit the file. -->
                        <xsl:when test="$result/url-open/errorcode = '196609'">
                            <operation type='{@type}' fault='Binary file not editable'>ERROR</operation> 
                        </xsl:when>
                        <!-- No error code provided, use default error -->
                        <xsl:otherwise>
                            <operation type='{@type}' fault='File could not be opened'>ERROR</operation> 
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <!-- No error: strip SOAP envelope from result -->
                <xsl:otherwise>
                    <xsl:copy-of select="$result/url-open/response//env:Envelope/env:Body/dpm:response/operation"/>
                </xsl:otherwise>  
          </xsl:choose>
        </xsl:when>   
        <xsl:otherwise>
            <operation type='{@type}' fault='Authentication failure'>ERROR</operation>  
        </xsl:otherwise>     
    </xsl:choose>
  </xsl:template>
  
  <!-- overwrite implied root matching template to preserve session-id -->
  <xsl:template match="/|*" mode="request">
    <xsl:param name="session" select="$sessionid"/>
    
    <xsl:apply-templates mode="request">
        <xsl:with-param name="session" select="$session"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="text()"/>
  <xsl:template mode="request" match="text()"/>

</xsl:stylesheet>
