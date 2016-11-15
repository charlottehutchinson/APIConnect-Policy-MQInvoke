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
    
    THIS FILE ONLY CONTAINS UNPROTECTED FUNCTIONS.
 
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
                xmlns:dpgui="http://www.datapower.com/extensions/webgui"
                extension-element-prefixes="dpgui">

  <xsl:output method="xml" encoding="utf-8" indent="yes"/>

  <!-- the following templates are in front of the MAP firewall,
       since they are called from outside a valid session -->
       
  <!-- box identification -->
  <xsl:template mode="request" match="operation[@type='get-ident']">
    <xsl:param name="session" select="$sessionid"/>
    
    <!-- request -->
    <xsl:variable name='ident'>
      <xsl:choose>
        <xsl:when test="function-available('dpgui:get-ident')">
          <xsl:copy-of select="dpgui:get-ident()/identification"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>

    <!-- output -->
    <operation type='{@type}'>
      <xsl:copy-of select="$ident"/>
    </operation>
  </xsl:template>

  <!-- list of domains on webgui login page -->
  <xsl:template mode="request" match="operation[@type='get-domain-list']">
    <xsl:param name="session" select="$sessionid"/>
    
    <!-- request -->
    <xsl:variable name='domains'>
      <xsl:choose>
        <xsl:when test="function-available('dpgui:get-domain-list')">
          <xsl:copy-of select="dpgui:get-domain-list()/domains"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>

    <!-- output -->
    <operation type='{@type}'>
      <xsl:copy-of select="$domains"/>
    </operation>
  </xsl:template>

  <!-- management interface ip on webgui login page -->
  <xsl:template mode="request" match="operation[@dmz='true' 
                                                and @type='get-config' 
                                                and request-class='EthernetInterface']">
                                                
    <xsl:param name="session" select="$sessionid"/>
    
    <!-- request -->
    <xsl:variable name="config">
      <xsl:choose>
        <xsl:when test="function-available('dpgui:get-config')">
          <xsl:copy-of select="dpgui:get-config('default', 'EthernetInterface', '', 0)/configuration"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>

    <!-- output -->
    <operation type='{@type}'>
        <xsl:copy-of select="$config"/>
    </operation>
  </xsl:template>

  <!-- management interface ip on webgui login page -->
  <xsl:template mode="request" match="operation[@dmz='true' 
                                                and @type='get-status' 
                                                and request-class='EthernetInterfaceStatus']">
                                                
    <xsl:param name="session" select="$sessionid"/>
    
    <!-- request -->
    <xsl:variable name="config">
      <xsl:choose>
        <xsl:when test="function-available('dpgui:get-config')">
          <xsl:copy-of select="dpgui:get-status('default', 'EthernetInterfaceStatus')/statistics"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>

    <!-- output -->
    <operation type='{@type}'>
        <xsl:copy-of select="$config"/>
    </operation>
  </xsl:template>

  <xsl:template mode="request" match="operation[@dmz='true' 
                                                and @type='get-status' 
                                                and (request-class='IPAddressStatus' or request-class='LinkStatus')]">
                                                
    <xsl:param name="session" select="$sessionid"/>
    
    <!-- request -->
    <xsl:variable name="status">
      <xsl:choose>
        <xsl:when test="function-available('dpgui:get-status')">
          <xsl:copy-of select="dpgui:get-status('default', request-class)/statistics"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>

    <!-- output -->
    <operation type='{@type}'>
        <xsl:copy-of select="$status"/>
    </operation>
  </xsl:template>
  
</xsl:stylesheet>
