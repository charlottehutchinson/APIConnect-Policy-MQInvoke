<?xml version="1.0" encoding="UTF-8" ?>
<!--
  Licensed Materials - Property of IBM
  IBM WebSphere DataPower Appliances
  Copyright IBM Corporation 2007, 2015. All Rights Reserved.
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


<!DOCTYPE xsl:stylesheet [
  <!ENTITY nbsp "&#160;">
]>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:dp="http://www.datapower.com/extensions"
  xmlns:func="http://exslt.org/functions"
  xmlns:set="http://exslt.org/sets"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
  xmlns:dpfunc="http://www.datapower.com/extensions/functions"
  extension-element-prefixes="dp"
  exclude-result-prefixes="dp func set xsd dpfunc">

  <xsl:import href="management.xsl"/>
  <xsl:include href="store:///dp/msgcat/webgui.xml.xsl" dp:ignore-multiple="yes"/>

  <xsl:variable name="quot">
    <xsl:text>"</xsl:text>
  </xsl:variable>

  <!-- a copy of the request, for reference in applied templates -->
  <xsl:variable name="request" select="/request"/>

  <xsl:variable name="lang">
    <xsl:choose>
      <xsl:when test="function-available('dp:variable')">
        <xsl:value-of select="dp:variable('var://context/webgui/lang')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="''"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="drMgmtDoc">
      <xsl:choose>
         <xsl:when test="not($lang) or $lang= 'en' or $lang= ''">
             <xsl:text>drMgmt.xml</xsl:text>
         </xsl:when>
         <xsl:otherwise>
             <xsl:text>drMgmt-</xsl:text>
             <xsl:value-of select="$lang"/>
             <xsl:text>.xml</xsl:text>
         </xsl:otherwise>
      </xsl:choose>
  </xsl:variable>

  <!-- FYI the file at this URL gets overwritten every time the process starts up -->
  <!-- IMPORTANT :: These MUST remain relative links.  
       SchemaUtil is used by the CLI for 'write mem' and making these absolute breaks that
  -->
  <xsl:variable name="schema" select="document($drMgmtDoc)/management-information"/>
  <xsl:variable name="basetypesDoc">
        <xsl:choose>
            <xsl:when test="not($lang) or $lang= 'en' or $lang= ''">                
                <xsl:text>basetypes.xml</xsl:text>           
            </xsl:when>
            <xsl:otherwise>
                <xsl:text>basetypes-</xsl:text>
                <xsl:value-of select="$lang"/>
                <xsl:text>.xml</xsl:text>               
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
  <xsl:variable name="basetypes" select="document($basetypesDoc)" />

  <!-- this is a flat list of types condensed from the two sources of type elements. -->

  <xsl:variable name="type-index" select="$basetypes//type | $schema//type" />

  <!-- for convenience, the list of all complex types -->
  <xsl:variable name="schema-complex-types" select="$type-index/self::type[@base='complex']" />

  <func:function name="dpfunc:get-complex-type">
      <xsl:param name="typeName" select="." />
      <func:result select="$schema-complex-types/self::type[@name=$typeName]" />
  </func:function>

  <xsl:variable name="schema-objects-index" select="$schema//object" />
  <xsl:variable name="schema-actions-index" select="$schema//action-objects//action" />

  <!-- for convenience, the list of all config objects -->
  <xsl:variable name="config-objects-index" select="$schema/config-objects//object" />

  <xsl:variable name="service-objects-index" select="$config-objects-index/self::object[(@multistep-enabled='true') or (ancestor::object[@name='Service'] and not(ancestor::object[@name='DeviceManagementService'])) and not(@internal='true') and not(@abstract='true')]"/>

  <func:function name="dpfunc:get-object-from-uri">
      <xsl:param name="uri" select="."/>
      <func:result select="$config-objects-index/child::*/child::object[uri=$uri]" />
  </func:function>

  <!-- for convenience, the list of all action objects -->
  <xsl:variable name="config-actions-index" select="$schema/action-objects//action" />

  <func:function name="dpfunc:schema-type">
      <xsl:param name="typeName"/>
      <func:result select="$type-index/self::type[@name=$typeName]"/>
  </func:function>
  
  <!-- Get the associated summary object of a service object -->
  <func:function name="dpfunc:get-summary-object">
    <xsl:param name="objName"/>

    <func:result select="$schema-objects-index/self::object[@name=string($objName)]/ancestor-or-self::*/status-bindings/status/@name"/>
  </func:function>

  <!-- find an object in the schema and return a nodeset of valid properties for it -->
  <!-- DEPRECATED:  use func call below -->
  <xsl:template name="schema-object-props">
    <xsl:param name="objname"/>
    <xsl:copy-of select="$schema-objects-index/self::object[@name=string($objname)]/ancestor-or-self::*/properties/property"/>
  </xsl:template>

  <!-- use this func call not template above -->
  <func:function name="dpfunc:schema-object-props">
      <xsl:param name="objname"/>
      <func:result select="$schema-objects-index/self::object[@name=string($objname)]/ancestor-or-self::*/properties/property"/>
  </func:function>

  <!-- return the display name for a config object -->
  <func:function name="dpfunc:property-display-name">
      <xsl:param name="propName"/>
      <xsl:param name="objname"/>
      <xsl:variable name="propIndex" select="dpfunc:schema-object-props($objname)"/>
      <xsl:variable name="objProp" select="$propIndex//self::property[@name=$propName]"/>
      <xsl:choose>
          <!-- simple property display -->
          <xsl:when test="$objProp/display != ''">
              <func:result select="$objProp/display"/>
          </xsl:when>
          <!-- complex type property display -->
          <xsl:when test="$schema-complex-types/self::type[@name=$propIndex/self::property/@type]/properties/property[@name=$propName]/display != ''">
              <func:result select="$schema-complex-types/self::type[@name=$propIndex/self::property/@type]/properties/property[@name=$propName]/display"/>
          </xsl:when>
          <!-- display the property name -->
          <xsl:otherwise>
              <func:result select="$propName"/>
          </xsl:otherwise>
      </xsl:choose>
  </func:function>

  <!-- this gets called a lot; use index lookup -->
  <xsl:key name="type-key" match="type" use="@name"/>

  <xsl:template name="schema-find-type">
      <xsl:param name="typeName"/>

      <xsl:variable name="schema-key">
          <xsl:for-each select="$schema">
        <xsl:copy-of select="key('type-key', $typeName)"/>
      </xsl:for-each>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$schema-key/*">
        <xsl:copy-of select="$schema-key/*"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="basetypes-key">
          <xsl:for-each select="$basetypes">
            <xsl:copy-of select="key('type-key', $typeName)"/>
          </xsl:for-each>
        </xsl:variable>
        <xsl:copy-of select="$basetypes-key/*"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="schema-find-type-with-prop">
      <xsl:param name="typeName"/>
      <xsl:param name="property" select="/.."/>

      <xsl:choose>
          <xsl:when test="($property//type[@name=$typeName])">
              <xsl:copy-of select="$property//type[@name=$typeName]"/>
          </xsl:when>
          <xsl:otherwise>
              <xsl:call-template name="schema-find-type">
                  <xsl:with-param name="typeName" select="$typeName"/>
              </xsl:call-template>
          </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

  <xsl:template name="schema-find-variable">
    <xsl:param name="varName"/>

    <xsl:variable name="typeName">
        <xsl:choose>
            <xsl:when test="starts-with($varName, 'var://system/')">
                <xsl:value-of select="'dmSystemVar'"/>
            </xsl:when>

            <xsl:when test="starts-with($varName, 'var://service/')">
                <xsl:value-of select="'dmServiceVar'"/>
            </xsl:when>

            <xsl:when test="contains($varName, '/_extension/')">
                <xsl:value-of select="'dmExtensionVar'"/>
            </xsl:when>

            <xsl:when test="contains($varName, '/local/')">
                <xsl:value-of select="'dmExtensionVar'"/>
            </xsl:when>
            <xsl:otherwise></xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:variable name="typeNode">
        <xsl:call-template name="schema-find-type">
            <xsl:with-param name="typeName" select="string($typeName)"/>
        </xsl:call-template>
    </xsl:variable>

    <xsl:choose>
        <xsl:when test="$typeNode/type/value-list/value[@name=$varName]">
            <xsl:copy-of select="$typeNode/type/value-list/value[@name=$varName]"/>
        </xsl:when>

        <xsl:when test="contains($varName, '/_extension/')">
            <xsl:variable name="localURL" 
                select="concat('var://local/_extension/', substring-after($varName,'/_extension/'))"/>

            <xsl:choose>
                <xsl:when test="$typeNode/type/value-list/value[@name=$localURL]">
                    <xsl:copy-of select="$typeNode/type/value-list/value[@name=$localURL]"/>
                </xsl:when>
                <xsl:when test="$typeNode/type/value-list/value[starts-with($localURL, @name)]">
                    <xsl:copy-of select="$typeNode/type/value-list/value[starts-with($localURL, @name)]"/>
                </xsl:when>
            </xsl:choose>
        </xsl:when>
    </xsl:choose>
  </xsl:template>

  <func:function name="dpfunc:get-property">
    <xsl:param name="objName" select="''"/>
    <xsl:param name="propName" select="''"/>

    <xsl:if test="not($objName = '' or $propName = '')">
        <func:result select="$schema-objects-index/self::object[@name=$objName]/ancestor-or-self::*/properties/property[@name=$propName]"/>
    </xsl:if>

  </func:function>

  <!-- find the type element for a given obj & property -->
  <func:function name="dpfunc:get-property-type">
    <xsl:param name="objName" select="''"/>
    <xsl:param name="propName" select="''"/>

    <xsl:variable name="temp" select="dpfunc:get-property($objName, $propName)"/>
    <xsl:if test="count($temp)">
        <func:result select="$type-index/self::type[@name=$temp/@type]"/>
    </xsl:if>

  </func:function>

  <!-- get the property of a complex type -->
  <func:function name="dpfunc:get-complex-property">
    <xsl:param name="typeName" />
    <xsl:param name="propName" />

    <xsl:if test="($typeName != '' and $propName != '')">
        <func:result select="$schema-complex-types/self::type[@name=$typeName]/properties/property[@name=$propName]"/>
    </xsl:if>

  </func:function>

  <!-- given a [config or status] object, find the applicable action elements. -->
  <func:function name="dpfunc:get-schema-object-actions">
    <xsl:param name="objname"/>
    <func:result select="$schema-objects-index/self::object[@name=string($objname)]/ancestor-or-self::*/actions/action"/>    
  </func:function>

  <!-- generate an object with all default properties -->
  <xsl:template name="schema-default-object">
    <xsl:param name="objClass"/>

    <xsl:variable name="properties">
      <xsl:call-template name="schema-object-props">
        <xsl:with-param name="objname" select="$objClass"/>
      </xsl:call-template>
    </xsl:variable>

    <xsl:element name="{$objClass}">

      <xsl:for-each select="$properties/property">

        <xsl:variable name="typeNode">
          <xsl:call-template name="schema-find-type">
            <xsl:with-param name="typeName" select="@type"/>
          </xsl:call-template>
        </xsl:variable>

        <!-- skip vectors -->
        <xsl:if test="not(@vector='true')">
          <xsl:element name="{@name}">
            <!-- propagate the needed static attributes of the property -->
            <xsl:copy-of select="@*[not(local-name()='name')]"/>
            <!-- determine default value -->
            <xsl:choose>
              <!-- simple complex -->
              <xsl:when test="($typeNode/type/@base='complex')">
                <xsl:call-template name="schema-default-complex">
                  <xsl:with-param name="typeName" select="@type"/>
                  <xsl:with-param name="typeNode" select="$typeNode"/>
                </xsl:call-template>
              </xsl:when>

              <xsl:when test="($typeNode/type/@base='bitmap')">
                <xsl:call-template name="schema-default-bitmap">
                  <xsl:with-param name="typeName" select="@type"/>
                  <xsl:with-param name="typeNode" select="$typeNode"/>
                  <xsl:with-param name="pdefault" select="default"/>
                </xsl:call-template>
              </xsl:when>

              <xsl:when test="default">
                <xsl:value-of select="default"/>
              </xsl:when>

              <xsl:when test="$typeNode/type/default">
                <xsl:message dp:priority="debug" dp:id="{$DPLOG_WEBGUI_DEFAULT_FOR_NAME}">
                  <dp:with-param value="{@name}"/>
                </xsl:message>
                <xsl:value-of select="$typeNode/type/default"/>
              </xsl:when>
            </xsl:choose>
          </xsl:element>
        </xsl:if>
      </xsl:for-each>

    </xsl:element>

  </xsl:template>

  <!-- generate a complex property with default values -->
  <xsl:template name="schema-default-complex">
    <xsl:param name="typeName"/>
    <xsl:param name="typeNode">
      <xsl:call-template name="schema-find-type">
        <xsl:with-param name="typeName" select="$typeName"/>
      </xsl:call-template>
    </xsl:param>

    <xsl:for-each select="$typeNode//properties/property">

      <xsl:variable name="subType">
        <xsl:call-template name="schema-find-type">
          <xsl:with-param name="typeName" select="@type"/>
        </xsl:call-template>
      </xsl:variable>

      <xsl:element name="{@name}">
        <!-- propagate the needed static attributes of the property -->
            <xsl:copy-of select="@*[not(local-name()='name')]"/>
        <!-- determine default value -->
        <xsl:choose>
          <xsl:when test="($subType/type/@base='bitmap')">
            <xsl:call-template name="schema-default-bitmap">
              <xsl:with-param name="typeName" select="@type"/>
              <xsl:with-param name="typeNode" select="$subType"/>
              <xsl:with-param name="pdefault" select="default"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="default">
            <xsl:value-of select="default"/>
          </xsl:when>
          <xsl:when test="$subType/default">
            <xsl:value-of select="$subType/default"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="''"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:element>
    </xsl:for-each>
  </xsl:template>

    <!-- generate a default bitmap property -->
    <xsl:template name="schema-default-bitmap">
        <xsl:param name="typeName" />
        <xsl:param name="typeNode">
            <xsl:call-template name="schema-find-type">
                <xsl:with-param name="typeName" select="$typeName" />
            </xsl:call-template>
        </xsl:param>
        <xsl:param name="pdefault" />

        <xsl:choose>
            <xsl:when test="normalize-space($pdefault) != '' and not( starts-with($pdefault, '0x') )">
                <xsl:variable name="default" select="concat('+', $pdefault, '+')" />
                <xsl:for-each select="$typeNode//value-list/value">
                    <xsl:element name="{@name}">
                        <xsl:choose>
                            <xsl:when test="(contains($default, concat('+', @name, '+')))">
                                <xsl:text>on</xsl:text>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:text>off</xsl:text>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:element>
                </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
                <xsl:for-each select="$typeNode//value-list/value">
                    <xsl:element name="{@name}">
                        <xsl:choose>
                            <xsl:when test="@default = 'true'">
                                <xsl:text>on</xsl:text>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:text>off</xsl:text>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:element>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
  </xsl:template>

  <xsl:template name="directory-filelist">
    <xsl:param name="directory-to-get"/>

    <xsl:variable name="filelistarg">
      <request>
        <operation type='get-filestore'>
          <location>
            <xsl:value-of select="$directory-to-get"/>
          </location>
        </operation>
      </request>
    </xsl:variable>
      
    <xsl:variable name="filelist">
      <xsl:call-template name="do-mgmt-request">
        <xsl:with-param name="request" select="$filelistarg"/>
      </xsl:call-template>
    </xsl:variable>

    <xsl:copy-of select="$filelist"/>
  </xsl:template>

  <!-- take an XML configuration nodeset and eliminate duplicate nodes -->
  <!-- here, equality is defined by same object class and name -->
  <!-- also, note that this isn't recursive; we're only processing the
       top-level nodes -->
  <!-- BZ 47789 - Moved xsl:key and de-duplication template to separate template
       to avoid performance overhead caused by having xsl:key in header of this 
       file -->
  <xsl:template name="unique-config">
      <xsl:copy-of select="dp:transform('webgui:///remove-duplicates.xsl', *)" />
  </xsl:template>

  <!-- for a given config alias name, return its class name -->
  <func:function name="dpfunc:objClass">
    <xsl:param name="objAlias" />
    <func:result select="$schema-objects-index/self::object[cli-alias/text()=$objAlias]/@name" />
  </func:function>

  <!-- for a given config object name, return its cli name -->
  <func:function name="dpfunc:objAlias">
    <xsl:param name="objName" />
    <func:result select="$schema-objects-index/self::object[@name=$objName]/cli-alias" />
  </func:function>

  <!-- for a given config object name, return its display name -->
  <func:function name="dpfunc:objDisplay">
    <xsl:param name="objName" />
    <func:result select="$schema-objects-index/self::object[@name=$objName]/display" />
  </func:function>

  <!-- for a given config object name, return its description -->
  <func:function name="dpfunc:objDescription">
    <xsl:param name="objName" />
    <func:result select="$schema-objects-index/self::object[@name=$objName]/description" />
  </func:function>

  <func:function name="dpfunc:propDisplay">
    <xsl:param name="objName" />
    <xsl:param name="propName"/>

    <xsl:variable name="prop" select="dpfunc:get-property($objName, $propName)"/>

    <func:result>
        <xsl:choose>
            <xsl:when test="$prop/display">
                <xsl:value-of select="$prop/display"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$prop/@name"/>
            </xsl:otherwise>
        </xsl:choose>
    </func:result>
  </func:function>

  <func:function name="dpfunc:valueDisplay">
    <xsl:param name="valueNode" />

    <xsl:choose>
        <xsl:when test="not($valueNode/display) or normalize-space($valueNode/display)=''">
            <func:result select="$valueNode/@name" />
        </xsl:when>
        <xsl:otherwise>
            <func:result select="$valueNode/display" />
        </xsl:otherwise>
    </xsl:choose>
  </func:function>

  <xsl:template name="add-url-attr">
      <xsl:param name="filestore"/>
      <xsl:apply-templates mode="add-url-attr" select="$filestore"/>
  </xsl:template>

  <xsl:template mode="add-url-attr" match="location/file[not(@url)]" priority="5">
      <xsl:copy>
          <xsl:apply-templates mode="add-url-attr" select="@*"/>
          <!-- add a url attribute so that it can be used in xpath-filter elements (see ProcessingStepAction.xsl) -->
          <xsl:attribute name="url">
              <xsl:value-of select="concat(../@name, '///', @name)"/>
          </xsl:attribute>
          <xsl:apply-templates mode="add-url-attr" select="node()"/>
      </xsl:copy>
  </xsl:template>

  <xsl:template mode="add-url-attr" match="directory/file[not(@url)]" priority="5">
      <xsl:copy>
          <xsl:apply-templates mode="add-url-attr" select="@*"/>
          <!-- add a url attribute so that it can be used in xpath-filter elements (see ProcessingStepAction.xsl) -->
          <xsl:attribute name="url">
              <xsl:value-of select="concat(substring-before(../@name, ':/'),
                                    ':///', substring-after(../@name, ':/'),
                                    '/', @name)"/>
          </xsl:attribute>
          <xsl:apply-templates mode="add-url-attr" select="node()"/>
      </xsl:copy>
  </xsl:template>

  <xsl:template mode="add-url-attr" match="file[not(@url)]">
      <xsl:copy>
          <xsl:apply-templates mode="add-url-attr" select="@*"/>
          <!-- add a url attribute so that it can be used in xpath-filter elements (see ProcessingStepAction.xsl) -->
          <xsl:attribute name="url">
              <!-- no location, no directory, we can't do much -->
              <xsl:value-of select="@name"/>
          </xsl:attribute>
          <xsl:apply-templates mode="add-url-attr" select="node()"/>
      </xsl:copy>
  </xsl:template>

  <xsl:template mode="add-url-attr" match="@*|node()">
      <xsl:copy>
          <xsl:apply-templates mode="add-url-attr" select="@*"/>
          <xsl:apply-templates mode="add-url-attr"/>
      </xsl:copy>
  </xsl:template>

    <func:function name="dpfunc:default-prop-value">
        <xsl:param name="objName" />
        <xsl:param name="propName"/>
        <xsl:variable name="prop" select="dpfunc:get-property($objName, $propName)"/>
        <func:result>
            <xsl:choose>
                <xsl:when test="$prop/default">
                    <xsl:value-of select="$prop/default"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="dpfunc:get-property-type($objName, $propName)/default"/>
                </xsl:otherwise>
            </xsl:choose>
        </func:result>
    </func:function>

</xsl:stylesheet>
