# PLCopen Technical Committee 6 - XML Formats for IEC 61131-3 (Version 2.01)

<!-- Page 1 -->
PLCopen 
for efficiency in automation 
  Total number of pages: 80 
 
 
 
 
 
Technical Paper 
PLCopen Technical Committee 6 
 
XML Formats for IEC 61131-3 
 
Version 2.01 – Official Release 
 
 
 
 
 
DISCLAIMER OF WARANTIES 
 
THIS DOCUMENT IS PROVIDED ON AN “AS IS” BASIS AND MAY BE SUBJECT TO 
FUTURE ADDITIONS, MODIFICATIONS, OR  CORRECTIONS. PLCOPEN HEREBY 
DISCLAIMS ALL WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING ANY 
WARRANTY OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE, FOR 
THIS DOCUMENT. IN NO EVENT WILL PLCOPEN BE RESPONSIBLE FOR ANY LOSS OR 
DAMAGE ARISING OUT OR RESULTING FROM ANY DEFECT, ERROR OR OMISSION IN 
THIS DOCUMENT OR FROM ANYONE’S USE OF OR RELIANCE ON THIS DOCUMENT. 
 
 
Copyright © 2003 - 2009 by PLCopen. All rights reserved. 
 
 
 
Date: May 08, 2009 

<!-- Page 2 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 2/80 
The following paper  
XML Formats for IEC 61131-3 
is a document representing the results of the wo rk done in the PLCopen Technical Committee 6 - 
XML. This release 2.1 is based on the work done on the version 2.0, ‘Official Release’, as published 
in December 2008, as well as the feedback receiv ed from in particular PLCopen Japan and 
AutomationML. There are only minor changes between both versions. 
This specification has been written thanks to the following members of the TC6 XML: 
 
Kevin Ketterle 3S 
Dirk Schubel 3S 
Rainer Drath ABB 
Annette Kratz ABB  
Josef Papenfort Beckhoff 
Uwe Thomas Beckhoff 
Thomas Brandl Bosch Rexroth 
René Simon FH Wernigerode 
Knut Güttel Helmut Schmidt Univ. 
Matthias Riedl ifak 
Wolfgang Horn IST 
Dietmar Berlesreiter Keba 
Andreas Weichelt KW Software 
Dimitrij Kirzhner KW Software 
Thomas Baier Logicals 
Hansjörg Hotz Panasonic 
Monique Atali-Ringot Rockwell Automation 
Paul Brooks Rockwell Automation 
Heinz Dieter Ferling Schneider Automation 
Jürgen Fiess Schneider Electrical Motion 
Hans Peter Otto Siemens 
Michael John Siemens 
Hajime Taruishi Toshiba / PLCopen Japan 
Les Powers Triconex 
Lorenz Hundt Univ. Magdeburg 
Arndt Lüder Univ. Magdeburg 
Eelco van der Wal PLCopen 
  
Contributors  
Björn Grimm Daimler 
Dirk Weidemann Zühlke 
 
Change Status List: 
Version 
number 
Date Change comment 
V 0.0 06/05/2002 Preliminary draft with additions from PLCopen 
V0.1 14/01/2003 Results of the meeting at infoteam software 
V 0.2 25/02/2003 Results of the meeting at Beckhoff Elektronik 
V 0.3 06/05/2003 Results of the meeti ng at Matsushita Electric Works 
V 0.4 17/06/2003 Results of the meeting at Kirchner SOFT 
V 0.5 15/07/2003 Results of the meeting in Amsterdam 

<!-- Page 3 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 3/80 
V 0.6 2/10/2003 Results of the meeting at KW Software, Lemgo, Germany 
V 0.7 28/11/2003 Results of the meeting in Ne urenberg, with further editing by EvdW 
V 0.71 31/03/2003 Hotz: All elements that describe IEC 61131-3 object are entered 
V 0.8 09/04/2004 Final version before release as 0.99 – EvdW 
V 0.99 16/04/2004 Released as Version 0.9 9 – in combination with scheme 
V 0.99 A 14/02/2005 Based on the feedback on the Version 0.99. Meeting Feb. 8+9, 05 
V 0.99 B 18/04/2005 Changed pictures included. US proof reading. 
V 1.0 27/04/2005 Last minor changes done. Ex amples added cf. new xsd. Official 
release 
V 1.01 10/06/2005 Minor update: “refLocalId” is  required. Text and examples updated. 
Add 04/04/2006 Addendum created to Versi on 1.01 as result of meeting April 2006 
Add V02 07/08/2006 Update Addendum as result of meeting July 28, 2006 
Add V03 24/04/2007 Addendum updated with additional feedback 
Add V04 11/03/2008 Addendum updated with additional feedback 
Add V041 19/05/2008 Update Addendum as result of meeting May 6, 2008 
Add V042 24/09/2008 Update Addendum as result of meeting Sept. 2, 2008 
Add V043 04/11/2008 As result of the meeting Nov. 4, 2008. Last version. 
V20P 07/11/2008 As result of the meeting Nov. 4, 2008. 
V20WD 21/11/2008 Sent to group for last editorial comments 
V 2.0 03/12/2008 Official Release of all merged feedback and decisions 
V 2.01 08/05/2009 Official Release of merged feedback and decisions 
 

<!-- Page 4 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 4/80 
 
Table of Contents 
1  INTRODUCTION....................................................................................................................6 
1.1. P URPOSE ..................................................................................................................................6 
1.2. S HORT INTRODUCTION INTO XML...........................................................................................7 
1.3. I MPORTANT CHANGES IN VERSION 2.0 AND V 2.01 AND COMPATIBILITY ISSUES......................8 
2 SCOPE..........................................................................................................................................9 
2.1. U SE CASE – EXCHANGE FORMAT FOR PROGRAMMING TOOLS (ALL IEC LANGUAGES)............. 9 
2.2. U SE CASE: INTERFACE TO PRODUCERS OF GRAPHICAL AND LOGICAL INFORMATION ...............9 
2.3. U SE CASE: INTERFACE TO CONSUMER OF GRAPHICAL AND LOGICAL INFORMATION. ...............9 
2.4. U SE CASE – DISTRIBUTION FORMAT FOR FUNCTION BLOCK LIBRARIES ...................................9 
2.5. G RAPHICAL OVERVIEW OF THE USE CASES..............................................................................9 
3 DEFINITIONS, COMPLIANCE, VALIDATION AND TRANSFORMATIONS............. 11 
3.1. D EFINITIONS ..........................................................................................................................11 
3.2. N AMING CONVENTIONS.........................................................................................................11 
3.3. C OMPLIANCE TO IEC 61131-3 – 2
ND
 EDITION ........................................................................11 
3.4. C OMPLIANCE TO SUPPLIER SPECIFIC EXTENSIONS ..................................................................11 
3.5. V ALIDATION, TRANSFORMATION AND REPRESENTATION OF XML DOCUMENTS ...................12 
3.6. F ORMATTED TEXT..................................................................................................................14 
3.7. D EFINITION OF THE COORDINATE SYSTEM FOR GRAPHICAL INFORMATION ............................14 
3.8. P OSITIONS..............................................................................................................................15 
3.9. D EFINITION OF THE EXECUTION ORDER OF THE GRAPHICAL ELEMENTS .................................17 
3.10. R EFERENCE OF GRAPHICAL ELEMENTS...................................................................................17 
4 OVERVIEW OF THE SCHEME EXPLANATION .............................................................18 
5 PROJECT STRUCTURE.........................................................................................................19 
5.1. H EADER INFORMATION OF AN XML FILE...............................................................................19 
5.2. H EADER ELEMENTS ...............................................................................................................19 
project/fileHeader ............................................................................................................. ........................................................... 19 
project/contentHeader.......................................................................................................... ........................................................ 20 
project/coordinateInfo......................................................................................................... ......................................................... 21 
5.3. ADDDATA AND ADDDATAINFO..............................................................................................21 
addDataInfo .................................................................................................................... ............................................................. 22 
addData........................................................................................................................ ................................................................ 22 
6 TYPE SPECIFIC PART...........................................................................................................23 
6.1. D EFINED DATATYPES ............................................................................................................23 
6.2. POU S.....................................................................................................................................24 
actions........................................................................................................................ .................................................................. 24 
transitions .................................................................................................................... ................................................................ 24 
body ........................................................................................................................... .................................................................. 25 
6.3. POU S – DECLARATION SECTION ............................................................................................26 
6.4. POU S – CODE SECTION ..........................................................................................................28 
6.4.1. General..............................................................................................................................28 
position ....................................................................................................................... ................................................................. 28 
relPosition.................................................................................................................... ................................................................ 28 
content ........................................................................................................................ ................................................................. 28 
variable ....................................................................................................................... ................................................................. 29 
expression..................................................................................................................... ............................................................... 29 
values......................................................................................................................... .................................................................. 29 
documentation .................................................................................................................. ........................................................... 29 
6.5. C OMMONALITIES OF GRAPHICAL LANGUAGES .......................................................................30 
Overview Common Objects........................................................................................................ ................................................. 30 
comment ........................................................................................................................ .............................................................. 30 

<!-- Page 5 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 5/80 
error .......................................................................................................................... ................................................................... 30 
connector ...................................................................................................................... ............................................................... 32 
connectionPointIn.............................................................................................................. .......................................................... 32 
connection..................................................................................................................... ............................................................... 33 
continuation ................................................................................................................... .............................................................. 34 
connectionPointOut ............................................................................................................. ........................................................ 34 
actionBlock.................................................................................................................... .............................................................. 35 
Additional information ......................................................................................................... ....................................................... 37 
vendorElement.................................................................................................................. ........................................................... 38 
6.5.1. SFC elements.....................................................................................................................39 
step........................................................................................................................... .................................................................... 40 
connectionPointOutAction....................................................................................................... .................................................... 41 
macroStep...................................................................................................................... .............................................................. 42 
jumpStep....................................................................................................................... ............................................................... 43 
transition..................................................................................................................... ................................................................. 44 
selectionDivergence............................................................................................................ ......................................................... 45 
selectionConvergence ........................................................................................................... ....................................................... 45 
simultaneousDivergence......................................................................................................... ..................................................... 46 
simultaneousConvergence ........................................................................................................ ................................................... 46 
6.5.2. FBD elements ....................................................................................................................47 
block .......................................................................................................................... .................................................................. 47 
inVariable ..................................................................................................................... ............................................................... 48 
outVariable .................................................................................................................... .............................................................. 48 
inoutVariable .................................................................................................................. ............................................................. 50 
label .......................................................................................................................... ................................................................... 51 
jump........................................................................................................................... .................................................................. 52 
return ......................................................................................................................... .................................................................. 53 
6.5.3. LD elements.......................................................................................................................54 
leftPowerRail.................................................................................................................. ............................................................. 54 
rightPowerRail................................................................................................................. ............................................................ 55 
coil........................................................................................................................... .................................................................... 56 
contact ........................................................................................................................ ................................................................. 57 
6.6. S CHEMA TEXTUAL LANGUAGES:........................................................................................... 58 
6.6.1. Structured Text (ST) and Instruction List (IL) ..................................................................58 
7 INSTANCE SPECIFIC PART.................................................................................................59 
7.1. CONFIGURATION ....................................................................................................................59 
7.2. RESOURCE..............................................................................................................................60 
7.3. TASK ......................................................................................................................................60 
7.4. POU  INSTANCES ....................................................................................................................61 
8 USE OF LOGO..........................................................................................................................62 
9 EXAMPLES...............................................................................................................................63 
9.1. O VERVIEW.............................................................................................................................63 
9.2. D ECLARATIVE PART OF PLCOPEN XML FILES......................................................................63 
9.3. U SE OF THE ADDDATA ELEMENT...........................................................................................64 
9.4. S IMPLE EXAMPLE FOR SFC ...................................................................................................65 
9.5. S IMPLE FBD EXAMPLE ..........................................................................................................71 
9.6. E XAMPLE CONNECTORS, CONNECTION AND VARIABLES ........................................................78 
9.7. E XAMPLE ON FORKED CONNECTIONS .....................................................................................80 
 

<!-- Page 6 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 6/80 
1  Introduction  
Since the release of the IEC 61131-3 programming standard, users want to  be able to exchange their 
programs, libraries and projects between development environments. Although this was not the intent 
of the standard itself, it was a task that the independent organization PLCopen committed itself to. 
 
IEC 61131-3 is focused on the software development envi ronment. As such it is just a part of a total 
solution. The other parts are a structure of tools like:  
• networking tools 
• debugging tools 
• simulators 
• documentation tools 
 
Therefore PLCopen had decided to develop interfaces towards these su pport tools. This has resulted 
in a workgroup named TC6 for XML (eXtended Mar kup Language). This committee has defined an 
open interface, which supports differe nt kinds of software tools, and provides the ability to transfer 
the information that is on the screen to other platforms. This screen information does not only contain 
textual information, but also graphical informati on. This can include the position and size of the 
function blocks, and how they are connected. 
The design of the ‘transferred’ program itself has to remain the same after the transfer, so not to be 
altered in look and feel. Th e wide variety of possibilities, especia lly in the graphical tools, has to be 
brought under one umbrella. Origina lly, PLCopen looked to the STEP st andard to do this. STEP can 
be looked at as an earlier version of XML, but the graphical part was limited. The STEP protocol was 
used for the PLCopen Portability Level, but showed a lack of graphical definitions. This meant that, 
without extensive work, the graphical languages could not be transferred, and the original goals could 
not be fulfilled. 
 
PLCopen wants to be able to transfer a control project without much addi tional effort, from one 
development environment to another without loosing information even when it is incomplete, e.g. not 
compilable without errors. This of course is also valid for the POUs, and especially for the User 
Derived Function Block libraries. XML provides the right technology for this. 
As such it will be more than an export / import tool from one development environment to another. 
From the moment that this format is available, it is just a small step to feed a documentation tool with 
the information, for instance. Actual ly, it is not important where th is XML-code is coming from, as 
long as it is recognizable and us eable. It could be generated by other tools like simulation and 
modeling tools, and consumed by verification, documentation, and version control tools. 
To support this principle, all relevant informa tion will be exported. The importing tool has to be 
intelligent in filtering which parts of this information are useful and needs to be imported. With this 
approach, PLCopen creates a complete new market, in  which the focus is on reusability of software 
development from libraries up to complete control projects. 
 
1.1. Purpose 
This document presents the representation of the complete project within the IEC 61131-3 
environment based on current XML technologie s, including the common elements with  Sequential 
Function Chart (SFC), the two textual languag es Structured Text (ST) and Instruction List (IL), and 
the two graphical languages Function Block Diagram  (FBD), and Ladder Diagram  (LD). The 
formats are specified through corresponding XML schema . This is an independe nt file, with the .xsd 

<!-- Page 7 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 7/80 
extension, and as such part of this specification. A description of these schema s is contained in this 
document. It is assumed that the reader of this document is familiar with the basic technologies. 
 
The described formats are destined fo r the import and export of IEC 61131-3 Projects and Program 
Organization Unit s (POUs). These items can be under development, and so incomplete. As such 
there is no verification on their applicability or their correctness.  
 
In principle all information is made available in  the exported XML file. The intelligence is in the 
importing function (One exception is the generation of the coordinate system information in free-
style graphical editors – this is generated in the export functionality)  
Vendor specific information and attributes can be included in the export file and possible deleted 
during import, if applicable. The su pplier specific information should not deal with a ny of the logic 
part of the program. 
 
This means that filtering is done on the import – suppliers have to take care that the extensions of the 
XML schemes for internal purposes is done in such a way that deletion of the info does not effect the 
functionality of the project. This  could be done via an additional,  supplier specific XML scheme, 
besides the PLCopen defined version, linked via an URL or file to the source. 
 
Concerning the exchange of graphical language c onstructs between different Programming Systems, 
the focus is on logical information with optional explicit graphics. 
 
Concerning consistency – the XML description is th e valid description. Other descriptions are added 
for clarification, etc., and no consistency to the XML description is guaranteed. 
 
1.2. Short introduction into XML 
XML stands for extended Markup Language, provi ding the basis for the well-known HTML (Hyper 
Text Markup Language) that is used extensively on the internet. 
XML has several advantages: 
1. It is extendable 
2. The data included can be checked for consistency with the scheme provided 
3. Different schemes provide a possibility to check the incompatibilities 
 
The W3C consortium calls XML "a common syntax for ex pressing structure in data." Structured data 
refers to data that is tagged for its content, m eaning, or use. For example,  whereas the <H1> tag in 
HTML specifies text to be presented in a certain  typeface and weight, an XML tag would explicitly 
identify the kind of information: <BYLINE> tags might identify the author of a document, <PRICE> 
tags could contain an item's cost in an inve ntory list - all the way dow n to <DOGFOODBRAND> if 
that's the level of detail required. 
 
A schema is defined as a formal specification of element names that indicates which elements are 
allowed in an XML document, and in what combin ations. It also define s the structure of the 
document: which elements are child elements of others, the sequence in which the child elements can 
appear, and the number of child elements. It defines whether an element is empty or can include text. 
The schema can also define default values for attributes. A schema also provides for extended 
functionality such as data typing, inheritance, and presentation rules. 
 
By separating structure and content from pres entation, the same XML source document can be 
written once, then displayed in a variety of ways : on a computer monitor, within a cellular-phone 

<!-- Page 8 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 8/80 
display, translated into voice on a device for th e blind, and so fort h. It will work on any 
communications devices that might be developed; an XML document ca n thus outlive the particular 
authoring and display technologies available when it was written. Check www.xml.org for more 
information. 
 
1.3. Important changes in version 2.0 and V 2.01 and compatibility issues 
During the implementation phases, several companies submitted feedback in the form of 
improvements and changes. These were discussed and decided upon within the TC6 Working Group. 
The main changes for Version 2.0 are: 
• Number of worksheets in POU body 
• SFC connectionPointIn missing 
• Actionblock: add height and wi dth attributes, add "localID" and "executionOrderId" and for 
‘Action’ add connectionPointOut 
• Include Anytype Datatypes 
• Add varAcccess and varConfig 
• Add global identifiers 
• Add possibility to add vendor specific data to elements 
• pouInstance: no way to specify type name 
The changes for Version 2.01 were in the graphics in Chapter 3.8 and the remark on pragmas, as well 
as two type definitions changed in the schema and one attribute. 
These updates should in practice not effect the upwards compatibility. 
 

<!-- Page 9 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 9/80 
2 Scope 
The scope of this specification is defined by identified “Use Cases”, focussed to the application areas 
in which these schemas could be used. The following uses cases have been identified: 
2.1. Use Case – Exchange format for programming tools (all IEC 
languages) 
• Exchange at POU or project level.  
• (One time) migration to another system – a certain amount of manual work could be needed 
• Parallel use of multiple systems - a certain amount of manual work could be needed 
The items can be under development, and so incomplete. As such there is no verification on their 
applicability, their consistency, or their correc tness. For less manual work during import, it is 
recommended that the data is consistent and valid when exported. 
 
2.2. Use Case: Interface to producers of graphical and logical information 
In this case the XML scheme provides an inte rface to a producing tool. An example of such a 
producer is a high level engineer ing tool that create s graphics and logical information on FB, 
program, and /or project level. 
The producer of graphical and logical information w ill generate an XML file . This XML file can be 
based on some lists or tables defining the component s to be used (e.g. parts of a plant) and on some 
template information for generating connections between these parts. 
One major requirement for continuous development is  the possibility to stor e custom data (e.g. a 
foreign key) with the elements in the generated XML and these elements s hould still be there when 
importing the XML into the programming tool and re-exporting to XML. This goal can be reached by 
specifying, in the XML, which attributes have to be preserved even if they are of no specific meaning 
for some XML processor. To support this, at thr ee levels custom data can be added to objects: 
Project, data- and POU type, and variable (including FB instances). 
 
2.3. Use Case: Interface to consumer of graphical and logical information.  
This use case provides an interf ace to supporting tools during the development phases, and is the 
counterpart of the use case above . Examples of consumers of in formation are validation tools, 
compilers, SCADA and HMI tools, as well as documentation generators; document management; 
source code database, version control, and document translation tools. 
 
2.4. Use Case – Distribution format for function block libraries  
This use case is focused to a format for distributi on of (user derived) func tions and function blocks 
specifically. With this, a user can create its own sour ce library of their func tions and function blocks 
as basis for different development systems. 
2.5. Graphical overview of the Use Cases  
The following picture provides an overview of thes e use cases. Horizontally is shown the import and 
export between tools of projects and POUs (use cas e 1 and 4). Vertically is  shown use case 2 (top) 
and 3 (bottom). 

<!-- Page 10 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 10/80 
 

<!-- Page 11 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 11/80 
3 Definitions, compliance, validation and transformations 
3.1. Definitions 
Project  A project consists of libraries and configurations. As such it contains a type part and 
an instance part. 
Library  A library is a collection of data-types and POU types. 
Element. Any item as defined in the XML specification 
Object  An element representing an (graphical) obj ect from a PLC project. All objects will 
get a local number as identification by the generating system. This number is called 
LocalId and shall be unique within a POU code body. Additionally objects may 
have an optional attribute globalId which is unique within the XML file. 
 
3.2. Naming Conventions 
Within the defined scheme, the following naming conventions are used: 
 
• Prefixes are non-capitalized 
• Identifiers start with lower case letter 
• Identifiers consisting of multiple words have the first character of each word after the prefix 
starting with a capital letter. No underscores are used 
• References to the ‘xsd’ elements are shown between double quotes, e.g. “element”. 
 
3.3. Compliance to IEC 61131-3 – 2nd edition 
This scheme is intended to be compliant to the second edition of the IEC 61131-3 standard. 
 
3.4. Remark on IEC 61131-3 Pragmas 
Pragma’s are the mechanism in IEC 61131-3 to defi ne “additional data” for elements. In XML this 
can be done via specific “addData”element, however is not specified here, but will be part of separate 
PLCopen published ‘Best practices’ schema addition to be published per application domain. 
 
3.5. Compliance to supplier specific extensions 
The goal is not to describe correct IEC 61131-3 POUs, but to represent a working state of the project, 
including extensions for layout and formatting. 
It is possible to export syntactical incorrect projects. Such a project could be an in-between version. 
For instance, within FBD several unconnected blocks can be seen  as a not-ready program, and as 
such can be exported by a system. 
 
There are certain non-compliant IEC 61131-3 items added at pre-defined positions in the XML 
scheme, for better exchange of supplier specific extensions. The following items are defined: 
• The support of pointers at datatypes 
• The support for an Enum Base Type other then INT 
• Persistent and non-persistent variables as LocalVars for Function Blocks 

<!-- Page 12 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 12/80 
• VarInOut can have the attribute CONSTANT 
• A Sub-sequence (like Macro) in SFC 
• A ‘JumpStep’ in SFC 
• A negated input (inverter) attr ibute at SFC transition conditi on input, step output, and action 
block output 
 
3.6. Validation, transformation and representation of XML Documents 
PLCopen has defined a schema which all certif ied programming systems must support. Every 
supplier can create and publish enhanced schemas,  in which the supplier specific properties are 
defined. These schemas can still be used within this context. 
The usage of the different schemas and XML documents is explained below. 
 
1. Flow for a well-defined document: 
 
ApplicationXML-Document XML-Parser
 ApplicationXML-Document XML-Parser
 
 
2. A valid XML-document is a well-defined XML- document of which the structure complies to 
a certain schema: 
Application
XML-Document
Schema
Validating
XML-Parser
 Application
XML-Document
Schema
Validating
XML-Parser
 
 
3. Transformation of Document of supplier X to a PLCopen XML document 
 
XML-Document X
XSLT Stylesheet
PLCopen XML 
Doc
XML-Document X
XSLT Stylesheet
PLCopen XML 
Doc
 
 

<!-- Page 13 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 13/80 
 
4. Representation of Document of supplier X combined with an XML Style sheet 
 
XML-Document X
XML Stylesheet X
Representation
XML-Document X
XML Stylesheet X
Representation
 
 
 
5. Extended usage of an XML Document 
 
Each supplier, which does not directly support the PLCopen Schema, has to provide 3 files: 
1. Their XML Scheme 
2. Their transformation file to the PLCopen scheme (XML Style sheet - XSLT) 
3. Their transformation from the PLCopen scheme (XSLT) 
 
Example 1: Programming system Y can import schema X 
 
Schema Y
Schema X
Schema PLCopen
Schema Y
Schema X
Schema PLCopen
 
 
Programming System X
Export
XML-Document
Programming System Y
Import
Schema Y
Validating 
XML- Parser
Schema X
XSLT (X ->PLCopen
deliver
Programming System X
Export
XML-Document
Programming System Y
Import
Schema Y
Validating 
XML- Parser
Schema X
XSLT (X ->PLCopen
deliver
 
 
 
Example 2: Programming system Y cannot import schema X 
 
Schema Y
Schema X
Schema PLCopen Schema Y
Schema X
Schema PLCopen
 
 

<!-- Page 14 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 14/80 
Export
Programming System Y
Import
Schema PLCopen
or
Schema Y
Validating
XML- Parser
Schema X
supply
XML-Document PLCopen
Programming System X XML-Document X
XSLT (X ->PLCopen
Export
Programming System Y
Import
Schema PLCopen
or
Schema Y
Validating
XML- Parser
Schema X
supply
XML-Document PLCopen
Programming System X XML-Document X
XSLT (X ->PLCopen
 
 
3.7. Formatted text 
The textual languages and documentation fields are represented as formatted text based on XHTML. 
 
3.8. Definition of the coordinate system for graphical information 
A coordinate system is mandatory for the export functionality of all the graphical languages.  
All graphical objects get mandatory coordinates, (X , Y), identifying the anchor point, relative to the 
origin, and in units. The origin (0, 0) equals top-left corner of th e worksheet. Positive X is to the 
right, and positive Y is down. Anchor points of elements always have positive coordinates; while 
relative reference points within the elements itself can have negative values. 
This information on coordinates can be ignored by the importing system, for instance when an auto-
routing / auto-placement system is in place. 
The graphical explanation below explains the relation. 
 System A System B 
Exporting System A: 
P export = (30/20) 
Scaling export = 10 
Importing System B: 
P import = (15/10) 
Scaling import = 5 
{ { 
P  P 
10 5
 
Figure 1 - Explanation of scaling factors for graphical information 

<!-- Page 15 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 15/80 
 
(note: for the importing system the applicable fo rmula is: Minimum Distance = CoordinateScaling * 
ApplicableCoordinate) 
X
import = Xexport * (Scalingimport / Scalingexport)  
 
Optionally, a page size is defined which lets app lications map from absolute coordinates in the 
coordinate system to some page and relative coordinate space (in units). 
 
For mapping of the coordinate information to the coordinate system, the following basis is mandatory 
for the export: 
• For FBD – the relation between the applicable  coordinate system used and the minimum 
distance between two pins, both for X and Y coordinates (CoordinateScaling) 
• For LD – both the X and Y coordinates are the size of a coil (not including the variable name) 
• For SFC – the size of a TRANSITION (width for X and height for Y) 
 
In case of <FBD>: 
ScalingX=h 
ScalingY=h 
In case of <LD>: 
ScalingX= w 
ScalingY= h 
 
 
In case of <SFC>: 
ScalingX= w 
ScalingY= h 
 
X-Y scale dataset of <fbd> element shall be used only for all of the objects of each <FBD> element. 
Similarly, <ld> is only for <LD> and <sfc> is only for <SFC>. The scaling for the Common 
Elements are based on the scaling of FBD. 
See Chapter 5 - project/coordinateInfo on page 21 for the XML representation. 
 
3.9. Positions 
The “position” child node of an obj ect specifies the position of the object’s anchor point. “position” 
has the attributes “x” and “y”. 
The anchor point of an object is the upper left co rner of the object rectangle. The object rectangle 
contains only the main body of the object. Attached elements like labels (i nstance name, coil name) 
or inverters shall not be considered for the size of this rectangle. 
The size of the object rectangle is specified by the “height” and “width” attributes of the object.  
 
Object Example 1 Example 2 
Step, MacroStep, jumpStep 
 
 
 
 

<!-- Page 16 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 16/80 
Object Example 1 Example 2 
transition 
 
 
         
  
 
selectionDivergence/Convergence, 
simultaneousDivergence/Convergence  
 
 
 
 
 
 
 
 
actionBlock  
 
 
block 
 
RS_1
RS
SET
RESET1
Q1 
 
inVariable, outVariable 
 
   
  
 
 
inOutVariable 
 
 
connector, continuation 
 
 
jump, return 
 
 
 
 
 
 

<!-- Page 17 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 17/80 
Object Example 1 Example 2 
leftPowerRail, rightPowerRail 
   
 
 
contact, coil 
(incl. connection point in and out) 
 
 
 
 
contact
comment
 
 
name
comment
 
 
 
3.10. Definition of the execution order of the graphical elements 
For Function Block Diagrams, there is a possibility to explicitly document the execution order of the 
blocks. According to the standard this is implementation dependent.  
A safer, explicit method has been used by providi ng an "executionId" attribute, which denotes the 
order of execution of all Functions and Function Blocks by unique integer numbers, and which is 
more flexible. 
 
3.11. Reference of graphical elements 
Every graphical element has a local ID for reference purposes. 
 
 

<!-- Page 18 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 18/80 
4 Overview of the scheme explanation 
The following chapters explain the PLCopen schema. For this, the following structure is used: 
 
• Project structure (chapter 5) 
 
• Type specific part (chapter 6) 
o Datatypes 
o POUs – declaration section and code for both the graphical and textual languages 
 
• Instance specific part (chapter 7) 
o Configuration 
o Resources 
o Tasks 
o Program instances 
o Global variables 
o Access paths 
 
The last two chapters deal with certification and examples. 
 

<!-- Page 19 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 19/80 
5 Project structure 
diagram: 
 
 
5.1. Header information of an XML file 
The file header and content header information orig inates from the publicly available specification of 
the IDA consortium and was specifically developed for usage in a context, where XML exchange 
files are generated from different tools of the same  or of different vendors. It therefore contains 
information on the file generation and on the versioning of the content. 
The content versioning information corresponds to the versioning information proposed for element 
types in Part 2 of the Functio n Block Standard IEC 61499. See th e "VersionInfo" element in the 
enclosed proposal for Derived Data Type encoding. 
5.2. Header elements 
project/fileHeader 
 
diagram: 
 
attributes: Name   Type   Use   Default   
companyName xsd:string required      
companyURL xsd:anyURI optional      
productName xsd:string required      
productVersion xsd:string required      
productRelease xsd:stri ng optional      
creationDateTime xsd:dateTime required      
contentDescription xsd:string optional       
 

<!-- Page 20 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 20/80 
The “FileHeader” element is used to provide in formation concerning the creation of the export / 
import file. Its mandatory attributes are the co mpany name, (with optional Company URL), with 
product name, version, release information, and the date and time of the cr eation of the file. An 
optional description of the content is included. 
Additionally the name of the company manufacturing and/or supplying the product may be included.  
The format of the date and time is in conformance with the W3C consortium specification. 
 
project/contentHeader 
 
diagram: 
 
attributes: Name   Type   Use   Default   
name xsd:string required      
version xsd:string optional      
modificationDateTime xsd:dateTime optional      
organization xsd:string optional      
author xsd:string optional      
language xsd:language optional       
 
The “contentHeader” element is used to provide overview information concerning the actual content 
of the export / import file. 
The "name" attribute is required. In case of exporting this attribute is set to the project name. 
The other attributes correspond to the equally named attributes of  the "VersionInfo" element as 
defined in IEC 61499-2. The "comment" element corr esponds to the "Remarks" attribute of the 
"VersionInfo" element. 
The attribute “language” is intended to specify the used language in the definition of the project.  
The “comment’ element consists of a string. 
The element “coordinateInfo” contains the inform ation for the mapping of the coordinate system. 
See: 
3.8 Definition of the coordinate system for graphical information. 
 

<!-- Page 21 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 21/80 
 
project/coordinateInfo 
diagram: 
 
 
element: pageSize 
diagram: 
 
attributes: Name   Type   Use   Default   
x xsd:decimal required      
y xsd:decimal required       
 
element: fbd 
diagram: 
 
element: ld 
diagram: 
 
element: sfc 
diagram: 
 
 
 
element: scaling 
diagram: 
 
attributes: Name   Type   Use   Default   
x xsd:decimal required      
y xsd:decimal required       
 
5.3. addData and addDataInfo 
For the project and certain objects  in the XML file the vendor can  include additional data. Such 
additional data is vendor-specific. The data itself is given in an addData object. Additionally in the 
addDataInfo an URI (uniform resource identifier) is given for the corresponding addData to uniquely 
identify the additional data elemen t content. In this name the ve ndor domain shall be included to 
ensure unique names. Using this name the importi ng tool may process the addData. The vendor shall 
specify the behavior of the importing tool in ca se the name is not known by the importing tool 

<!-- Page 22 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 22/80 
especially regarding a later export from this t ool. In the following description of elements the 
addData is not considered. 
 
addDataInfo 
 
diagram: 
 
 
element: addDataInfo/info 
diagram: 
 
attributes: Name   Type   Use   Default   
name xsd:anyURI required      
version xsd:decimal       
vendor xsd:anyURI required       
 
addData 
 
diagram: 
 
 
element: addData/data 
diagram: 
 
attributes: Name   Type   Use   Default   
name xsd:anyURI required      
handleUnknown derived by: 
xsd:NMTOKEN 
required      
 
 

<!-- Page 23 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 23/80 
6 Type specific part 
6.1. Defined Datatypes 
A datatype can be either an elementary type: 
BOOL, BYTE, WORD, DWORD, LWORD, SINT, INT, DINT, LINT, USINT, UINT, UDINT, 
ULINT, REAL, LREAL, TIME, DATE, DT, TOD, STRING, WSTRING; 
 
a derived type: 
ARRAY, DERIVED, ENUM, SUBRANGESIGNED, SUBRANGEUNSIGNED, STRUCT; 
 
a generic type: 
ANY, ANY_DERIVED, ANY_ELEMENTARY, ANY_MAGNITUDE, ANY_NUM, ANY_REAL, 
ANY_INT, ANY_BIT, ANY_STRING, ANY_DATE; 
 
or an extended type: 
POINTER. 
 
Notes: 
• The string types additionally are defined by an optional string length. 
• DERIVED is a reference to a user defined data type  or POU. Variable declarations use this type 
to declare for instance function block instances. 
• ENUM is an enumerated type and is defined by a list of required values  and one optional base 
type. 
• SUBRANGESIGNED and SUBRANGEUNSIGNED ar e defined by a required range and a 
required base type. The range of SUBRA NGESIGNED is ‘long’ and the range of 
SUBRANGEUNSIGNED is ‘unsigned long’. 
• STRUCT is a structured type and is defined by a list of variables. 
• In addition to the IEC 61131-3 stan dard, a datatype can be of th e type POINTER. A pointer is 
defined by its required base type. 
 

<!-- Page 24 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 24/80 
 
6.2. POUs 
POUs consist of zero or more POU ‘s. A POU is defined as: 
 
diagram: 
 
attributes: Name   Type   Use   Default   
name xsd:string required      
pouType ppx:pouType required      
globalId xsd:ID optional       
 
The “interface” element contains the declaration in formation (see hereunder). The code section is 
represented as a list of actions, transitions, or a body. Documentation can be added to a POU element. 
 
actions 
The element “actions” can consist of zero or more elements of type “action”. These consist of zero of 
more elements of “body” and optional “documentation”. 
 
transitions
 
The element “transitions” can consist of zero or more  elements of type “transition”. These consist of 
zero of more elements of “body” and optional “documentation”. 
 

<!-- Page 25 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 25/80 
body 
A POU has a collection of several b odies. This is useful to organize  the POU in smaller sections, so 
called worksheets. These worksheets are executed in the same order as they are listed in the XML 
file. 
diagram: 
 
attributes: Name   Type   Use   Default   
WorksheetName xsd:string optional      
globalId xsd:ID optional       
 

<!-- Page 26 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 26/80 
 
6.3. POUs – declaration section 
element: project/types/pous/pou/interface 
diagram: 
 
 
 
The interface of a POU represents a return type (F unctions), and a list of seve ral kinds of variables: 
local variables, temporary variables, input variables, output variables, input/output variables, external 
variables, global variables and access path variables. They are defined with the same XML structure, 
with the same attributes. For example: 

<!-- Page 27 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 27/80 
 
element: localVars 
diagram: 
 
attributes: Name   Type   Use   Default   
name xsd:string optional      
constant xsd:boolean optional   false   
retain xsd:boolean optional   false   
nonretain xsd:boolean optional   false   
persistent xsd:boolean optional   false   
nonpersistent xsd:boolean optional   false    
 
 
A variable or variable list is defined by an optional “name”, and an optional “documentation”. 
Also following attributes can be defined: constant, retain, no retain, persistent and non persistent. 
The global variables are listed here also, and not under Chapter 7 Instance specific part. 
 

<!-- Page 28 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 28/80 
6.4. POUs – code section 
 
6.4.1. General 
Following elements will be used to describe objects in graphical languages: 
 
position 
diagram: 
 
attributes: Name   Type   Use   Default   
x xsd:decimal required      
y xsd:decimal required       
 
The element “position” is used to express coordina te values. Both coordinate values “x” and “y” are 
of type unsigned integer. 
 
relPosition
 
diagram: 
 
attributes: Name   Type   Use   Default   
x xsd:decimal required      
y xsd:decimal required       
Relative position of the connection pin. The origin is the anchor of the block. 
 
content 
diagram: 
 
 
The element “content” is represented as formatted text. 
 

<!-- Page 29 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 29/80 
 
variable 
diagram: 
 
attributes Name   Type   Use   Default   
name xsd:string required      
adress xsd:string optional      
globalID xsd:ID optional       
 
The element “variable” is a valid IEC 61131-3 variable e.g. avar[0] 
 
expression 
diagram: 
 
 
The operand is a valid IEC variable e.g. avar[0] or an IEC expression or multiple token text e.g. a + b 
(*sum*). An IEC 61131-3 parser has to be used to extract variable information. 
 
values 
diagram: 
 
 
A value contains a required name and an optional value, both as strings. 
 
documentation 
diagram: 
 
 
The element “Documentation” contains formatted text. 
 

<!-- Page 30 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 30/80 
 
6.5. Commonalities of graphical languages 
The following objects, as defined in “commonObject s”, can be used in a ny graphical body and have 
no direct IEC 61131-3 scope. 
 
Overview Common Objects 
The Common Objects are a collection of objects which have  no direct IEC scope and can be used in 
any graphical body. The graphical representation is as follows: 
 
diagram: 
 
 
comment 
diagram 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal required      
width xsd:decimal required      
globalId xsd:ID optional       
 
The element “comment” is used to store arbitrary text strings, which are not associated with a graphic 
location. They are for example presented inside  a dialog box/dialog window within the GUI. 
“comment” elements are sparsely used in language elements. 
 
error 

<!-- Page 31 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 31/80 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal required      
width xsd:decimal required      
globalId xsd:ID optional       
 
Like the element “comment”, the element “error” is used to store text strings inside a rectangular 
frame, 
• Which is associated with a graphic location and, 
• Which has a defined height and width. 
 
In contrast to the comment box, the error box and the text inside that box are automatically created by 
software utilities to indicate failures during conversion operations. Examples of those utilities are 
language converters for legacy languages. They create the error boxes at locations where the 
corresponding graphical objects would have been created in case of correct conversion. 
 

<!-- Page 32 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 32/80 
connector 
diagram: 
 
attributes: Name   Type   Use   Default   
name xsd:string required      
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
globalId xsd:ID optional       
 
connectionPointIn 
diagram: 
 
attributes: Name   Type   Use   Default   
globalId xsd:ID optional       
 
 

<!-- Page 33 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 33/80 
connection 
diagram: 
 
attributes: Name   Type   Use   Default   
globalId xsd:ID optional      
refLocalId   xsd: unsignedLong   required      
formalParameter xsd:string required       
 
A “connection” describes a graphical coupling be tween a data consuming element (e.g. an input 
variable) and another element, which provides the da ta (output variable, and normally is in front of 
the father element, so right to left). It may co ntain a list of positions that  describes the path or 
trajectory of the connection. If positions are export ed, the starting point (e.g. input) and the end point 
(e.g. output) are part of the list (although redundant). 
If no position information is provided, the link must be routed automatically. 
“refLocalId” identifies the element the connection starts from.  
If present, “formalParameter” specifies the element’s output the connection starts from. 
“formalParameter” either denotes the name of  the VAR_OUTPUT / VAR_IN _OUT parameter of a 
POU block or refers to the “formalParameter” at tribute of the correspo nding “connectionPointOut”. 
If this “formalParameter” is not present: 
• If the “refLocalId” attribute refers to a POU block, the start of the connection is the first 
output of this block, which is not ENO. 
• If the “refLocalId” attribute refers to any other element type, the start of the connection is the 
elements single native output. 
 

<!-- Page 34 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 34/80 
continuation 
diagram: 
 
attributes: Name   Type   Use   Default   
name xsd:string required      
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
globalId xsd:ID optional       
 
connectionPointOut 
This is the counterpart of the connector element. For this reason it has a simpler “connectionPoint”: 
diagram: 
 
attributes: Name   Type   Use   Default   
globalId xsd:ID optional       
 
 

<!-- Page 35 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 35/80 
actionBlock 
These are part of the common objects because their scope is beyond SFC. 
 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
negated xsd:boolean optional   false   
width xsd:decimal optional      
height xsd:decimal optional      
executionOrderId xsd:uns ignedLong optional      
globalId xsd:ID optional       
 

<!-- Page 36 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 36/80 
 
element: action 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
qualifier derived by: 
xsd:NMTOKEN 
optional   N   
width xsd:decimal optional      
height xsd:decimal optional      
duration xsd:string optional      
indicator xsd:string optional      
executionOrderId xsd:uns ignedLong optional      
globalId xsd:ID optional       
 
The element “reference” is a string, containing the name of an action or Boolean variable. 
The element “inline” is referencing to the in line implementation of an action body. 

<!-- Page 37 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 37/80 
 
element: inline 
diagram: 
 
attributes: Name   Type   Use   Default   
WorksheetName xsd:string optional      
globalId xsd:ID optional       
 
Additional information 
The following objects can be used in any graphical body and have no direct IEC 61131-3 scope, 
 
• A textual comment string not belonging to the graphical pane. 
• A textual error description generated by language converters. 
• Free floating lines, without any connections, will not be exported in the graphical languages, 
which can have an effect on POUs that are not yet readily defined. 
 

<!-- Page 38 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 38/80 
 
vendorElement 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
width xsd:decimal optional      
height xsd:decimal optional      
executionOrderId xsd:uns ignedLong optional      
globalId         
 
element: alternativeText 
diagram: 
 
 
 

<!-- Page 39 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 39/80 
 
6.5.1. SFC elements 
 
The SFC elements contain a collec tion of objects, which are defined in SFC. They can only be used 
in SFC bodies. 
 
diagram: 
 
 

<!-- Page 40 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 40/80 
step 
The element ‘step’ provides a single step in a SFC Sequence. Actions are associated with a step by 
using an actionBlock element with a connection to the step element. 
 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
name xsd:string required      
initialStep xsd:boolean optional   false   
negated xsd:boolean optional   false   
executionOrderId xsd:uns ignedLong optional      
globalId xsd:ID optional       
Note: there is no finalStep attribute. This is either explicit connected or via an export of jumpStep. 
 

<!-- Page 41 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 41/80 
 
connectionPointOutAction 
 
diagram: 
 
attributes: Name   Type   Use   Default   
globalId xsd:ID optional      
formalParameter xsd:string required       
 

<!-- Page 42 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 42/80 
macroStep 
This element is beyond the IEC 61131-3 scope. It provide s a graphical representation of several steps 
and transitions into one element. 
 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
name xsd:string optional      
executionOrderId xsd:uns ignedLong optional      
globalId xsd:ID optional       
 
The macroStep body can consist of any of th e IEC 61131-3 programming la nguages, incl. SFC. 
Documentation is optional to it. 
 

<!-- Page 43 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 43/80 
jumpStep 
This element is beyond the IEC 61131-3 scope. It prov ides a graphical repres entation of jump to a 
label coupled to a step. 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
targetName xsd:string required      
executionOrderId xsd:uns ignedLong optional      
globalId xsd:ID optional       
 

<!-- Page 44 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 44/80 
 
transition 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
priority xsd:unsignedLong optional      
executionOrderId xsd:uns ignedLong optional      
globalId xsd:ID optional       
 
The “condition” can either contain a reference, a connection, or inline code programmed in any of the 
five languages. 
 

<!-- Page 45 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 45/80 
selectionDivergence 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
globalId xsd:ID optional       
 
selectionConvergence 
diagram: 
 
attributes: Name   Type   Use   Default   Fixed   
localId xsd:unsignedLong required         
height xsd:decimal optional         
width xsd:decimal optional         
globalId xsd:ID optional          
 
 

<!-- Page 46 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 46/80 
simultaneousDivergence 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
name xsd:string optional      
globalId xsd:ID optional       
 
simultaneousConvergence 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
globalId xsd:ID optional       

<!-- Page 47 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 47/80 
6.5.2. FBD elements 
 
These elements are a collection of objects, which are defined in FBD. They can be used in all 
graphical bodies. 
diagram: 
 
 
block 
A block is a graphical representation of an operation on a function or a function block. 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
width xsd:decimal optional      
height xsd:decimal optional      
typeName xsd:string required      
instanceName xsd:string optional      
executionOrderId xsd:uns ignedLong optional      
globalId xsd:ID optional       

<!-- Page 48 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 48/80 
 
The three types of variables each contain zero or more variables. The input variable can have an 
element “connectionPointIn”. The output variable  can have an element “connectionPointOut”. The 
inOutVariable can have a “connectionPointIn” and a “connectionPointOut”. 
 
inVariable 
The element “inVariable” represents  an input variable. Th e input variable can be  negated; an edge 
modifier and a storage modifier can be entered. 
The element “edge” of type “edgeModifierType” de fines the edge detection behaviour (rising / 
falling / none) of a variable. 
The “storage” element of type “storageModifierType” defines the storage mode behaviour (set / reset 
/ none) of a variable. 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
executionOrderId xsd:uns ignedLong optional      
negated xsd:boolean optional   false   
edge ppx:edgeModifierType optional   none   
storage ppx:storageModifierType optional   none   
globalId xsd:ID optional       
 
outVariable 
The element “outVariable” represents an output variable. The output variable can be negated; an edge 
modifier and a storage modifier can be entered. 
The element “edge” defines the edge detection behaviour (rising / falling / none) of a variable. 
The element “storage” defines the storage mode behaviour (set / reset / none) of a variable. 
 

<!-- Page 49 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 49/80 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
executionOrderId xsd:uns ignedLong optional      
negated xsd:boolean optional   false   
edge ppx:edgeModifierType optional   none   
storage ppx:storageModifierType optional   none   
globalId xsd:ID optional       
 

<!-- Page 50 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 50/80 
inoutVariable 
The element “inoutVariable” represents an inout va riable. The input and the output can be negated; 
an edge modifier and a storage modifier can be entered. 
The element “edge” defines the edge detection behaviour (rising / falling / none) of a variable. 
The element “storage” defines the storage mode behaviour (set / reset / none) of a variable. 
 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
executionOrderId xsd:uns ignedLong optional      
negatedIn xsd:boolean optional   false   
edgeIn ppx:edgeModifierType optional   none   
storageIn ppx:storageModifierType optional   none   
negatedOut xsd:boolean optional   false   
edgeOut ppx:edgeModifierType optional   none   
storageOut ppx:storageModifierType optional   none   
globalId xsd:ID optional       
 

<!-- Page 51 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 51/80 
label 
The element “label” is the target of a jump. 
 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
label xsd:string required      
executionOrderId xsd:uns ignedLong optional      
globalId xsd:ID optional       
 

<!-- Page 52 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 52/80 
jump 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
label xsd:string required      
executionOrderId xsd:uns ignedLong optional      
globalId xsd:ID optional       
 

<!-- Page 53 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 53/80 
return 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
executionOrderId xsd:unsignedLong optional      
globalId xsd:ID optional       
 

<!-- Page 54 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 54/80 
 
6.5.3. LD elements 
 
These elements describe a collection of objects, wh ich are defined in LD, and are an extension to 
FBD. They can be used in LD and SFC bodies 
diagram: 
 
 
leftPowerRail 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
executionOrderId xsd:uns ignedLong optional      
globalId xsd:ID optional       
 

<!-- Page 55 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 55/80 
rightPowerRail 
 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
executionOrderId xsd:uns ignedLong optional      
globalId xsd:ID optional       
 

<!-- Page 56 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 56/80 
coil 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
executionOrderId xsd:uns ignedLong optional      
negated xsd:boolean optional   false   
edge ppx:edgeModifierType optional   none   
storage ppx:storageModifierType optional   none   
globalId xsd:ID optional       
 

<!-- Page 57 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 57/80 
contact 
diagram: 
 
attributes: Name   Type   Use   Default   
localId xsd:unsignedLong required      
height xsd:decimal optional      
width xsd:decimal optional      
executionOrderId xsd:uns ignedLong optional      
negated xsd:boolean optional   false   
edge ppx:edgeModifierType optional   none   
storage ppx:storageModifierType optional   none   
globalId xsd:ID optional       
 

<!-- Page 58 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 58/80 
 
6.6. Schema Textual Languages: 
 
6.6.1. Structured Text (ST) and Instruction List (IL) 
The textual languages are represented as formatted text based on XHTML. 
 

<!-- Page 59 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 59/80 
7 Instance specific part 
Instances can contain a “configurations” element,  which consists of zero or more elements 
“configuration”. 
7.1. configuration 
The element “configuration” represents a group of resources and global variables. It is identified by a 
required name. 
diagram: 
 
attributes: Name   Type   Use   Default   
name xsd:string required      
globalId xsd:ID optional       
 

<!-- Page 60 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 60/80 
 
7.2. resource 
The element “resource” represents a group of programs, tasks and global variables. It is identified by 
a required name. 
diagram: 
 
attributes: Name   Type   Use   Default   
name xsd:string required      
globalId xsd:ID optional       
 
7.3. task 
The element “task” represents a periodic or triggered task and consists of a group of program and / or 
function block instances. It is defined by a requir ed priority, an optional single, and an optional 
interval time. 

<!-- Page 61 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 61/80 
 
diagram: 
 
attributes: Name   Type   Use   Default   
name xsd:string required      
single xsd:string optional      
interval xsd:string optional      
priority derived by: 
xsd:integer 
required      
globalId xsd:ID optional       
 
7.4. POU instances 
The element “pouInstance” represents a program or function block instance either running with or 
without a task. 
 
diagram: 
 
attributes: Name   Type   Use   Default   
name xsd:string required      
typeName xsd:string required      
globalId xsd:ID optional       
 

<!-- Page 62 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 62/80 
8 Use of Logo 
PLCopen members, which have submitted their relevant files and which are published on the 
PLCopen website, do fulfil the basic requirements, and can use the following logo: 
 
 
 
This logo is owned and trademarked by PLCopen. 
 
The mentioned relevant files can include: 
1. Their XML Scheme 
2. Their transformation file to the PLCopen scheme (XML Stylesheet - XSLT) 
3. Their transformation from the PLCopen scheme (XSLT) 
 
In order to use this logo free-of-charge, the relevant company has to fulfill all the following 
requirements: 
1. The company has to be a voting member of PLCopen; 
2. The company has to comply to the existing specification, as specified by the PLCopen 
Technical Committee 6 – XML, and as published by PLCopen, and of which this statement is 
a part; 
3. This compliance application is provided in writt en form by the company to PLCopen, clearly 
stating the applicable software package and th e supporting elements as specified in this 
document; 
4. In case of non-fulfillment, which has to be decided by PLCopen, the company will receive a 
written statement concerning this from PLCopen. The company will have a one month period 
to either adopt their software package in su ch a way that it complies, represented by the 
issuing of a new compliance statement, or remo ve all reference to the specification, including 
the use of the logo, from all their material, be it technical or promotional; 
5. The logo has to be used as is - meaning the full  logo. it may be altered in size as long as the 
original scale and color setting is kept. 
6. The logo has to be used in the context of PLCopen XML. 
 
Concerning certification a separate document is curre ntly under construction. It will be applicable 
after publication on the PLCopen website. 

<!-- Page 63 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 63/80 
9 Examples 
9.1. Overview 
The following subchapters demonstrate the use of PLCopen XML with some short examples. These 
examples are: 
- The XML representation of the declarative part of the PLCopen file,  
- An Example for the use of the “addData” Element, 
- a simple SFC example, 
- a simple FBD example, 
- an example connectors, connection and variables,  
- and an example on forked connections 
 
All examples include a short description of the depicted item, the XML code of the PLCopen XML 
file and if available the graphical representation.   
 
9.2. Declarative Part of PLCopen XML Files 
Within this Example the common declarative part of a PLCopen file is depicted. 
 
XML output  
<?xml version="1.0" encoding="UTF-8"?> 
<project xmlns="http://www.plcopen.org/xml/tc6_0200"  
xmlns:ns1="http://www.plcopen.org/xml/tc6.xsd"  
xmlns:xhtml="http://www.w3.org/1999/xhtml"  
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"  
xsi:schemaLocation="http://www.plcopen.org/xml/tc6_0200 http://www.plcopen.org/xml/tc6_0200"> 
 <!--Information about the creation of the file-->  
 <fileHeader  companyName ="plcopen" 
   creationDateTime ="2008-11-04T18:20:00" 
   productName ="plcopen"  
   productVersion ="2"/>    
 <contentHeader name="prj"> 
  <!--Basis for coordination systems--> 
  <coordinateInfo> 
   <fbd> 
    <scaling x="8" y="8"/> 
   </fbd> 
   <ld> 
    <scaling x="8" y="8"/> 
   </ld> 
   <sfc> 
    <scaling x="8" y="8"/> 
   </sfc> 
  </coordinateInfo> 
 </contentHeader> 
 <types> 
  <dataTypes/> 
  <pous/> 
 </types> 
 <instances> 
  <configurations/> 
 </instances> 
</project> 

<!-- Page 64 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 64/80 
 
9.3. Use of the addData Element 
The following example depicts the use of the addData mechanism  
 
XML output  
 
</contentHeader> 
.. 
<!-- Delaration of AdditonalData --> 
 <addDataInfo> 
  <info name="http://www.anyVendor.org/Vendor_AddData" vendor="http://www.anyVendor.org"> 
   <description> 
    <xhtml:p>Text description of additional data</xhtml:p> 
   </description> 
  </info> 
 </addDataInfo> 
</contentHeader> 
… 
<!-- Use of Additional Data as extension of an action --> 
<action name="Interrutable"> 
…  
<addData> 
<data  name=”http://www.anyVendor.org/Vendor_AddData” 
handleUnknown="implementation"> 
   <AddDataRoot> 
    <FirstElement ExampleAttribute1="PLCopen_extention"  /> 
    <SecondAttribute/> 
   </AddDataRoot> 
  </data> 
</addData> 
</action> 
…. 
 

<!-- Page 65 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 65/80 
 
9.4. Simple Example for SFC 
The following example depicts a simple SFC. The XM L output for this example is delivered in two 
versions.  The first version show s simplified how the structure of the SFC is represented with 
PLCopen XML and the second version contains th e full XML file including all declarations and 
graphical information 
 
Graphical representation  
S0
S2S1
Var1
Var1
Var1
Var2
Var1
 
 
XML output  
 
Version1  
 
Note this version doesn’t contain any graphical information 
…  
<SFC> 
 <step initialStep="true" localId="1" name="S0"> 
  <connectionPointIn> 
   <connection refLocalId="12"/> 
  </connectionPointIn> 
  <connectionPointOut formalParameter="sfc"/> 
  <connectionPointOutAction formalParameter="x"/> 
 </step> 
 
 <outVariable localId="2"> 
  <connectionPointIn> 
   <connection refLocalId="1" formalParameter="x"/> 
  </connectionPointIn> 
  <expression>Var3</expression> 
 </outVariable> 
 
 <inVariable localId="3" negated="true"> 
  <connectionPointOut/> 
  <expression>Var1</expression> 
 </inVariable> 
 
 <transition localId="4" > 

<!-- Page 66 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 66/80 
  <connectionPointIn> 
   <connection refLocalId="1" formalParameter="sfc"/> 
  </connectionPointIn> 
  <connectionPointOut/> 
  <condition> 
   <connectionPointIn> 
    <connection refLocalId="3"/> 
   </connectionPointIn> 
  </condition> 
 </transition> 
 
 <simultaneousDivergence localId="4"> 
  <connectionPointIn> 
   <connection refLocalId="4"/> 
  </connectionPointIn> 
  <connectionPointOut formalParameter="0"/> 
  <connectionPointOut formalParameter="160"/> 
 </simultaneousDivergence> 
 
 <step localId="6" name="S1" > 
  <connectionPointIn> 
   <connection refLocalId="5" formalParameter="0"/> 
  </connectionPointIn> 
  <connectionPointOut formalParameter="sfc"/> 
  <connectionPointOutAction formalParameter="x"/> 
 </step> 
 
 <outVariable localId="7" negated="true"> 
  <connectionPointIn> 
   <connection refLocalId="6" formalParameter="x"/> 
  </connectionPointIn> 
  <expression>Var4</expression> 
 </outVariable> 
 
 <step localId="8" name="S2"> 
  <connectionPointIn> 
   <connection refLocalId="5" formalParameter="0"/> 
  </connectionPointIn> 
  <connectionPointOut formalParameter="sfc"/> 
  <connectionPointOutAction formalParameter="x"/> 
 </step> 
 
 <outVariable localId="9" negated="true"> 
  <connectionPointIn> 
   <connection refLocalId="8"> 
   </connection> 
  </connectionPointIn> 
  <expression>Var5</expression> 
 </outVariable> 
 
 <simultaneousConvergence localId="10"> 
  <connectionPointIn> 
   <connection refLocalId="6" formalParameter="sfc"/> 
  </connectionPointIn> 
  <connectionPointIn> 
   <connection refLocalId="8" formalParameter="sfc"/> 
  </connectionPointIn> 
  <connectionPointOut/> 
 </simultaneousConvergence> 
 

<!-- Page 67 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 67/80 
 <inVariable localId="11"> 
  <connectionPointOut/> 
  <expression>Var2</expression> 
 </inVariable> 
 
 <transition localId="12"> 
  <connectionPointIn> 
   <connection refLocalId="10" formalParameter="sfc"/> 
  </connectionPointIn> 
  <connectionPointOut/> 
  <condition negated="true"> 
   <connectionPointIn> 
    <connection refLocalId="3"/>    
   </connectionPointIn> 
  </condition> 
 </transition> 
</SFC> 
 
Version2 
 
<?xml version="1.0" encoding="UTF-8"?> 
<project xmlns="http://www.plcopen.org/xml/tc6_0200"  
xmlns:ns1="http://www.plcopen.org/xml/tc6.xsd"  
xmlns:xhtml="http://www.w3.org/1999/xhtml"  
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"  
xsi:schemaLocation="http://www.plcopen.org/xml/tc6_0200 http://www.plcopen.org/xml/tc6_0200"> 
 <fileHeader companyName="plcopen"  
      creationDateTime ="2008-11-04T18:20:00"  
      productName ="plcopen"   
      productVersion ="2"/> 
 <contentHeader name="prj"> 
  <coordinateInfo>    
   <fbd> 
    <scaling x="8" y="8"/> 
   </fbd> 
   <ld> 
    <scaling x="8" y="8"/> 
   </ld> 
   <sfc> 
    <scaling x="8" y="8"/> 
   </sfc> 
  </coordinateInfo> 
 </contentHeader> 
 <types> 
  <dataTypes/> 
  <pous> 
   <pou name="sfc1" pouType="program"> 
    <interface> 
     <localVars retain="false"> 
      <variable name="Var1"> 
       <type> 
        <BOOL/> 
       </type> 
      </variable> 
      <variable name="Var2"> 
       <type> 
        <BOOL/> 
       </type> 
      </variable> 
      <variable name="Var3"> 

<!-- Page 68 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 68/80 
       <type> 
        <BOOL/> 
       </type> 
      </variable>       
      <variable name="Var4"> 
       <type> 
        <BOOL/> 
       </type> 
      </variable> 
      <variable name="Var5"> 
       <type> 
        <BOOL/> 
       </type> 
      </variable>       
     </localVars> 
    </interface> 
    <actions/> 
    <transitions/> 
    <body> 
     <SFC> 
      <step initialStep="true" localId="1" width="32" height="32" name="S0"> 
       <position x="480" y="96"/> 
       <connectionPointIn> 
        <relPosition x="16" y="0"/> 
        <connection refLocalId="12"> 
         <position x="496" y="96"/> 
         <position x="496" y="88"/> 
         <position x="376" y="88"/> 
         <position x="376" y="352"/> 
         <position x="496" y="344"/> 
        </connection> 
       </connectionPointIn> 
       <connectionPointOut formalParameter="sfc"> 
        <relPosition x="16" y="32"/> 
       </connectionPointOut> 
       <connectionPointOutAction formalParameter="x"> 
        <relPosition x="32" y="16"/> 
       </connectionPointOutAction> 
      </step>   
             
      <outVariable localId="2" width="80" height="16"> 
       <position x="640" y="104"/> 
       <connectionPointIn> 
        <relPosition x="0" y="8"/> 
        <connection refLocalId="1" formalParameter="x"> 
         <position x="640" y="112"/> 
         <position x="496" y="112"/> 
        </connection> 
       </connectionPointIn> 
       <expression>Var3</expression>      
      </outVariable>  
       
      <inVariable localId="3" width="80" height="16" negated="true"> 
       <position x="240" y="184"/> 
       <connectionPointOut> 
        <relPosition x="80" y="8"/>         
       </connectionPointOut> 
       <expression>Var1</expression>      
      </inVariable> 
       

<!-- Page 69 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 69/80 
      <transition localId="4" width="32" height="8"> 
       <position x="480" y="188"/> 
       <connectionPointIn> 
        <relPosition x="16" y="-12"/> 
        <connection refLocalId="1" formalParameter="sfc"> 
         <position x="496" y="176"/> 
         <position x="496" y="128"/> 
        </connection> 
       </connectionPointIn> 
       <connectionPointOut> 
        <relPosition x="16" y="24"/> 
       </connectionPointOut> 
       <condition> 
        <connectionPointIn> 
         <connection refLocalId="3"> 
          <position x="480" y="192"/> 
          <position x="320" y="192"/>      
  
         </connection> 
        </connectionPointIn>         
       </condition> 
      </transition> 
       
      <simultaneousDivergence localId="4" width="160" height="4"> 
       <position x="416" y="214"/> 
       <connectionPointIn> 
        <relPosition x="80" y="0"/> 
        <connection refLocalId="4"> 
         <position x="416" y="214"/> 
         <position x="416" y="212"/> 
        </connection> 
       </connectionPointIn> 
       <connectionPointOut formalParameter="0"> 
        <relPosition x="0" y="4"/> 
       </connectionPointOut> 
       <connectionPointOut formalParameter="160"> 
        <relPosition x="160" y="4"/> 
       </connectionPointOut> 
      </simultaneousDivergence> 
        
         <step localId="6"  name="S1" width="32" height="32"> 
       <position x="400" y="232"/> 
       <connectionPointIn> 
        <relPosition x="16" y="0"/> 
        <connection refLocalId="5" formalParameter="0"> 
         <position x="416" y="232"/> 
         <position x="416" y="218"/>        
        </connection> 
       </connectionPointIn> 
       <connectionPointOut formalParameter="sfc"> 
        <relPosition x="16" y="32"/> 
       </connectionPointOut> 
       <connectionPointOutAction  formalParameter="x"> 
        <relPosition x="32" y="16"/> 
       </connectionPointOutAction> 
      </step>  
      
      <outVariable localId="7" width="80" height="16" negated="true"> 
       <position x="640" y="216"/> 
       <connectionPointIn>         

<!-- Page 70 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 70/80 
        <connection refLocalId="6" formalParameter="x"> 
         <position x="640" y="224"/> 
         <position x="440" y="224"/> 
         <position x="440" y="248"/> 
         <position x="432" y="248"/> 
        </connection> 
       </connectionPointIn> 
       <expression>Var4</expression>      
      </outVariable> 
       
      <step localId="8"  name="S2" width="32" height="32"> 
       <position x="560" y="232"/> 
       <connectionPointIn> 
        <relPosition x="16" y="0"/> 
        <connection refLocalId="5" formalParameter="0"> 
         <position x="576" y="232"/> 
         <position x="276" y="218"/>        
        </connection> 
       </connectionPointIn> 
       <connectionPointOut formalParameter="sfc"> 
        <relPosition x="16" y="32"/> 
       </connectionPointOut> 
       <connectionPointOutAction  formalParameter="x"> 
        <relPosition x="32" y="16"/> 
       </connectionPointOutAction> 
      </step> 
       
      <outVariable localId="9" width="80" height="16" negated="true"> 
       <position x="640" y="216"/> 
       <connectionPointIn> 
        <relPosition x="0" y="8"/> 
        <connection refLocalId="8" > 
         <position x="640" y="248"/> 
         <position x="592" y="248"/>     
        </connection> 
       </connectionPointIn> 
       <expression>Var5</expression>      
      </outVariable>      
             
      <simultaneousConvergence localId="10" width="160" height="4"> 
       <position x="416" y="2863"/> 
       <connectionPointIn> 
        <relPosition x="0" y="0"/> 
        <connection refLocalId="6" formalParameter="sfc"> 
         <position x="416" y="286"/> 
         <position x="416" y="264"/> 
        </connection> 
       </connectionPointIn> 
       <connectionPointIn> 
        <relPosition x="80" y="4"/> 
        <connection refLocalId="8" formalParameter="sfc"> 
         <position x="576" y="286"/> 
         <position x="576" y="264"/> 
        </connection> 
       </connectionPointIn> 
       <connectionPointOut> 
        <relPosition x="80" y="4"/> 
       </connectionPointOut> 
      </simultaneousConvergence> 
       

<!-- Page 71 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 71/80 
      <inVariable localId="11" width="80" height="16" > 
       <position x="240" y="320"/> 
       <connectionPointOut> 
        <relPosition x="80" y="8"/>         
       </connectionPointOut> 
       <expression>Var2</expression>      
      </inVariable> 
       
      <transition localId="12" width="32" height="8"> 
       <position x="480" y="324"/> 
       <connectionPointIn> 
        <relPosition x="16" y="-12"/> 
        <connection refLocalId="10" formalParameter="sfc"> 
         <position x="496" y="312"/> 
         <position x="496" y="290"/> 
        </connection> 
       </connectionPointIn> 
       <connectionPointOut> 
        <relPosition x="16" y="24"/> 
       </connectionPointOut> 
       <condition negated="true"> 
        <connectionPointIn> 
         <connection refLocalId="3"> 
          <position x="480" y="328"/> 
          <position x="320" y="328"/>    
         </connection> 
        </connectionPointIn>         
       </condition> 
      </transition>       
     </SFC> 
    </body>     
   </pou> 
  </pous> 
 </types> 
 <instances> 
  <configurations/> 
 </instances> 
</project> 
 
9.5. Simple FBD example 
The following example depicts a simple FBD. The XM L output for this example is delivered in two 
versions.  The first version shows simplified how the structure of the FBD is represented with 
PLCopen XML and the second version contains th e full XML file including all declarations and 
graphical information 
 
Graphical representation  
 

<!-- Page 72 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 72/80 
 
XML output  
 
Version1  
 
Note this version doesn’t contain any graphical information 
 
<FBD> 
 <inVariable localId="1"> 
  <connectionPointOut/> 
  <expression>Var4</expression> 
 </inVariable> 
  
 <inVariable localId="2"> 
  <connectionPointOut/> 
  <expression>1</expression> 
 </inVariable> 
  
 <block localId="3" typeName="ADD" instanceName="ADD"> 
  <inputVariables> 
   <variable formalParameter="IN1"> 
    <connectionPointIn> 
     <connection refLocalId="1"/> 
    </connectionPointIn> 
   </variable> 
   <variable formalParameter="IN2"> 
    <connectionPointIn> 
     <connection refLocalId="2"/> 
    </connectionPointIn> 
   </variable> 
  </inputVariables> 
  <inOutVariables/> 
  <outputVariables> 
   <variable formalParameter="OUT1"> 
    <connectionPointOut/> 
   </variable> 
  </outputVariables> 
 </block> 
  
 <inVariable localId="4"> 
  <connectionPointOut/> 
  <expression>Var1</expression> 
 </inVariable> 
  
 <inVariable localId="5"> 
  <connectionPointOut/> 
  <expression>Var2</expression> 
 </inVariable> 
  
 <inVariable hlocalId="6"> 
  <connectionPointOut/> 
  <expression>TRUE</expression> 
 </inVariable> 
  
 <block instanceName="MUX1" localId="7" typeName="MUX"> 
  <inputVariables> 
   <variable formalParameter="K"> 
    <connectionPointIn> 
     <connection formalParameter="OUT1" refLocalId="3"/> 

<!-- Page 73 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 73/80 
    </connectionPointIn> 
   </variable> 
   <variable formalParameter="IN1"> 
    <connectionPointIn> 
     <connection refLocalId="4"/> 
    </connectionPointIn> 
   </variable> 
   <variable formalParameter="IN2" negated="true"> 
    <connectionPointIn> 
     <connection refLocalId="5"/> 
    </connectionPointIn> 
   </variable> 
   <variable formalParameter="IN3"> 
    <connectionPointIn> 
     <connection refLocalId="6"/> 
    </connectionPointIn> 
   </variable> 
   <variable formalParameter="IN4" negated="true"> 
    <connectionPointIn/> 
   </variable> 
   <variable formalParameter="IN5"> 
    <connectionPointIn/> 
   </variable> 
  </inputVariables> 
  <inOutVariables/> 
  <outputVariables> 
   <variable formalParameter="OUT1" negated="true"> 
    <connectionPointOut/> 
   </variable> 
  </outputVariables> 
 </block> 
  
 <outVariable localId="8"> 
  <connectionPointIn> 
   <connection formalParameter="OUT1" refLocalId="7"/> 
  </connectionPointIn> 
  <expression>Var3</expression> 
 </outVariable> 
</FBD> 
 
Version2 
 
<?xml version="1.0" encoding="UTF-8"?> 
<project xmlns="http://www.plcopen.org/xml/tc6_0200"  
xmlns:ns1="http://www.plcopen.org/xml/tc6.xsd"  
xmlns:xhtml="http://www.w3.org/1999/xhtml"  
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"  
xsi:schemaLocation="http://www.plcopen.org/xml/tc6_0200 http://www.plcopen.org/xml/tc6_0200"> 
 <fileHeader companyName="plcopen"  
      creationDateTime ="2008-11-04T18:20:00"  
      productName ="plcopen"   
      productVersion ="2"/> 
 <contentHeader name="prj"> 
  <coordinateInfo> 
   <fbd> 
    <scaling x="16" y="16"/> 
   </fbd> 
   <ld> 
    <scaling x="16" y="16"/> 
   </ld> 

<!-- Page 74 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 74/80 
   <sfc> 
    <scaling x="16" y="16"/> 
   </sfc> 
  </coordinateInfo> 
 </contentHeader> 
 <types> 
  <dataTypes/> 
  <pous> 
   <pou name="FBD1" pouType="functionBlock"> 
    <interface> 
     <localVars> 
      <variable name="Var1"> 
       <type> 
        <BOOL/> 
       </type> 
      </variable> 
      <variable name="Var2"> 
       <type> 
        <BOOL/> 
       </type> 
      </variable> 
      <variable name="Var3"> 
       <type> 
        <BOOL/> 
       </type> 
      </variable> 
      <variable name="Var4"> 
       <type> 
        <INT/> 
       </type> 
       <initialValue> 
        <simpleValue value="1"/> 
       </initialValue> 
      </variable> 
     </localVars> 
    </interface> 
    <body> 
     <FBD> 
      <inVariable height="16" localId="1" width="80"> 
       <position x="80" y="32"/> 
       <connectionPointOut> 
        <relPosition x="80" y="8"/> 
       </connectionPointOut> 
       <expression>Var4</expression> 
      </inVariable> 
      <inVariable height="16" localId="2" width="80"> 
       <position x="80" y="48"/> 
       <connectionPointOut> 
        <relPosition x="80" y="8"/> 
       </connectionPointOut> 
       <expression>1</expression> 
      </inVariable> 
<block height ="32" localId ="3" typeName ="ADD" instanceName ="ADD" 
width="32"> 
       <position x="240" y="32"/> 
       <inputVariables> 
        <variable formalParameter="IN1"> 
         <connectionPointIn> 
          <relPosition y="8" x="0"/> 
          <connection refLocalId="1"> 

<!-- Page 75 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 75/80 
           <position x="240" y="40"/> 
           <position x="160" y="40"/> 
          </connection> 
         </connectionPointIn> 
        </variable> 
        <variable formalParameter="IN2"> 
         <connectionPointIn> 
          <relPosition y="24" x="0"/> 
          <connection refLocalId="2"> 
           <position x="240" y="56"/> 
           <position x="160" y="56"/> 
          </connection> 
         </connectionPointIn> 
        </variable> 
       </inputVariables> 
       <inOutVariables/> 
       <outputVariables> 
        <variable formalParameter="OUT1"> 
         <connectionPointOut> 
          <relPosition x="32" y="8"/> 
         </connectionPointOut> 
        </variable> 
       </outputVariables> 
      </block> 
      <inVariable height="16" localId="4" width="80"> 
       <position x="160" y="80"/> 
       <connectionPointOut> 
        <relPosition x="80" y="8"/> 
       </connectionPointOut> 
       <expression>Var1</expression> 
      </inVariable> 
      <inVariable height="16" localId="5" width="80"> 
       <position x="160" y="96"/> 
       <connectionPointOut> 
        <relPosition x="80" y="8"/> 
       </connectionPointOut> 
       <expression>Var2</expression> 
      </inVariable> 
      <inVariable height="16" localId="6" width="80"> 
       <position x="160" y="112"/> 
       <connectionPointOut> 
        <relPosition x="80" y="8"/> 
       </connectionPointOut> 
       <expression>TRUE</expression> 
      </inVariable> 
      <block height="96" instanceName="MUX1" localId="7" typeName="MUX"  
           w i d t h ="48"> 
       <position x="320" y="64"/> 
       <inputVariables> 
        <variable formalParameter="K"> 
         <connectionPointIn> 
          <relPosition x="0" y="8"/> 
          <connection formalParameter="OUT1" refLocalId="3"> 
           <position x="320" y="72"/> 
           <position x="312" y="72"/> 
           <position x="312" y="40"/> 
           <position x="272" y="40"/> 
          </connection> 
         </connectionPointIn> 
        </variable> 

<!-- Page 76 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 76/80 
        <variable formalParameter="IN1"> 
         <connectionPointIn> 
          <relPosition x="0" y="24"/> 
          <connection refLocalId="4"> 
           <position x="320" y="88"/> 
           <position x="160" y="88"/> 
          </connection> 
         </connectionPointIn> 
        </variable> 
        <variable formalParameter="IN2" negated="true"> 
         <connectionPointIn> 
          <relPosition x="0" y="40"/> 
          <connection refLocalId="5"> 
           <position x="320" y="104"/> 
           <position x="160" y="104"/> 
          </connection> 
         </connectionPointIn> 
        </variable> 
        <variable formalParameter="IN3"> 
         <connectionPointIn> 
          <relPosition x="0" y="56"/> 
          <connection refLocalId="6"> 
           <position x="320" y="120"/> 
           <position x="160" y="120"/> 
          </connection> 
         </connectionPointIn> 
        </variable> 
        <variable formalParameter="IN4" negated="true"> 
         <connectionPointIn> 
          <relPosition x="0" y="72"/> 
         </connectionPointIn> 
        </variable> 
        <variable formalParameter="IN5"> 
         <connectionPointIn> 
          <relPosition x="0" y="88"/> 
         </connectionPointIn> 
        </variable> 
       </inputVariables> 
       <inOutVariables/> 
       <outputVariables> 
        <variable formalParameter="OUT1" negated="true"> 
         <connectionPointOut> 
          <relPosition x="48" y="8"/> 
         </connectionPointOut> 
        </variable> 
       </outputVariables> 
      </block> 
      <outVariable height="16" localId="8" width="80"> 
       <position x="400" y="64"/> 
       <connectionPointIn> 
        <relPosition x="0" y="8"/> 
        <connection formalParameter="OUT1" refLocalId="7"> 
         <position x="400" y="72"/> 
         <position x="368" y="72"/> 
        </connection> 
       </connectionPointIn> 
       <expression>Var3</expression> 
      </outVariable> 
     </FBD> 
    </body> 

<!-- Page 77 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 77/80 
   </pou> 
  </pous> 
 </types> 
 <instances> 
  <configurations/> 
 </instances> 
</project> 
 

<!-- Page 78 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 78/80 
9.6. Example connectors, connection and variables 
The following example depicts the representation of  connectors, connections and variables with 
PLCopen XML. The XML output for this example contains the FBD part only. 
 
Graphical representation  
 
 
 
XML output  
 
<FBD> 
 <inVariable height="16" localId="1" width="80"> 
  <position x="160" y="32"/> 
  <connectionPointOut> 
   <relPosition x="80" y="8"/> 
  </connectionPointOut> 
  <expression>Var1</expression> 
 </inVariable> 
  
 <connector name="C1" localId="10" height="16" width="80"> 
  <position x="240" y="32"/> 
  <connectionPointIn> 
   <relPosition x="0" y="8"/> 
   <connection refLocalId="1"> 
    <position x="240" y="40"/> 
    <position x="160" y="40"/> 
   </connection> 
  </connectionPointIn> 
 </connector> 
  
 <continuation name="C1" localId="11" height="16" width="80"> 
  <position x="400" y="32"/> 
  <connectionPointOut> 
   <relPosition x="80" y="8"/> 
  </connectionPointOut> 
 </continuation> 
  
 <continuation name="C1" localId="12" height="16" width="80"> 
  <position x="400" y="48"/> 
  <connectionPointOut> 
   <relPosition x="80" y="8"/> 
  </connectionPointOut> 
 </continuation> 
  
 <outVariable height="16" localId="2" negated="true" width="80"> 
  <position x="480" y="32"/> 
  <connectionPointIn> 
   <relPosition x="0" y="8"/> 
   <connection refLocalId="11"> 
    <position x="480" y="40"/> 
    <position x="400" y="40"/> 
   </connection> 
  </connectionPointIn> 
  <expression>Var2</expression> 
 </outVariable> 

<!-- Page 79 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 79/80 
  
 <outVariable height="16" localId="3" width="80"> 
  <position x="480" y="48"/> 
  <connectionPointIn> 
   <relPosition x="80" y="8"/> 
   <connection refLocalId="12"> 
    <position x="480" y="56"/> 
    <position x="400" y="56"/> 
   </connection> 
  </connectionPointIn> 
  <expression>Var3</expression> 
 </outVariable> 
  
</FBD> 
 

<!-- Page 80 -->
PLCopen 
for efficiency in automation 
TC6 XML  © PLCopen (2004 .. 2009)  
Version 2.01 – Official release 08/05/2008  page 80/80 
9.7. Example on forked connections 
 
The following example depicts the representation of a forked connection with PLCopen XML. The 
XML output for this example contains the FBD part only. 
 
Graphical representation  
 
 
 
XML output 
 
 
<FBD> 
 <inVariable localId="1" height="16" width="80"> 
  <position x="80" y="32"/> 
  <connectionPointOut> 
   <relPosition x="80" y="8"/> 
  </connectionPointOut> 
  <expression>Var1</expression> 
 </inVariable> 
 
 <outVariable localId="2" height="16" width="80"> 
  <position x="240" y="48"/> 
  <connectionPointIn> 
   <relPosition x="0" y="8"/> 
   <connection refLocalId="1"> 
    <position x="240" y="56"/> 
    <position x="200" y="56"/> 
    <position x="200" y="40"/> 
    <position x="160" y="40"/> 
   </connection> 
  </connectionPointIn> 
  <expression>Var3</expression> 
 </outVariable> 
 
 <outVariable localId="3" height="16" width="80"> 
  <position x="240" y="64"/> 
  <connectionPointIn> 
   <relPosition x="0" y="8"/> 
   <connection refLocalId="1"> 
    <position x="240" y="72"/> 
    <position x="200" y="72"/> 
    <position x="200" y="56"/> 
    <position x="200" y="40"/> 
    <position x="160" y="40"/> 
   </connection> 
  </connectionPointIn> 
  <expression>Var2</expression> 
 </outVariable> 
</FBD> 
 
 