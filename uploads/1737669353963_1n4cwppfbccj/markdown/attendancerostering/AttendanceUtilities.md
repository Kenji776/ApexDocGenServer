# AttendanceUtilities Class

shared utilities used by features in the attendance tracking business unit. Includes functions for creating test data, getting daily rosters for businesses, 
performing checkin/checkout operations and more. 
NOTE: Currenly set to without sharing as the profile for the community user does not have full access to the Enrollment__c records that are required to operate this class.

**Name** 

AttendanceUtilities

**Demo One** 

```apex
   //Generate test check in data by creating a new business license, associated accounts, contacts, and attendance__c records

   map<string,list<sObject>> testData = AttendanceUtilities.generateTestAttendanceData(null, 25, 1);
   BusinessLicense thisLicense = testData.get('BusinessLicense')[0];

   //find all the enrollees in our business licence
   list<AttendanceUtilities.EnrollmentWrapper> enrollees = AttendanceUtilities.getAllLicenseEnrollees(thisLicense.Id);

   //get an attendance roster that will contain a placeholder attendance record for every enrollee
   AttendanceUtilities.RosterWrapper roster = AttendanceUtilities.getAttendanceRoster(thisLicense.Id, Date.today());

   //set each of our attendees to being checked in
   for(AttendanceUtilities.AttendeeWrapper thisAttendee : roster.attendees){
       thisAttendee.checkedIn = true;
   }

   //update our attendance records
   list<AttendanceUtilities.AttendeeWrapper> checkInResults = AttendanceUtilities.setCheckedInStatus(roster.attendees);

   system.debug(JSON.serializePretty(checkInResults));
```

**Demo Two** 

```apex
   //Generate Test Data for All Business Licenses that don't have any enrollments

   list<BusinessLicense> bl = [SELECT Id, Name, (Select Id from Enrollments__r) from BusinessLicense where id in (Select Business_License__c From Enrollment__c)];

   for(BusinessLicense thisBl : bl){
       system.debug('\n\n\n------- ' + thisBl.Name + ' Has ' + thisBl.Enrollments__r.size() + ' Enrollments!');
       if(thisBl.Enrollments__r.isEmpty()){
           AttendanceUtilities.generateTestAttendanceData(thisBl.Id, 25, 1);
       }
   }
```

**Group** AttendanceRostering

**Author** Slalom

**Date** 1/17/2024

## Fields
### `CONTACT_PROGRAM_PARTICIPATION`

#### Signature
```apex
public static CONTACT_PROGRAM_PARTICIPATION
```

#### Type
string

---

### `CHILD_CONTACT_RECORD_TYPE`

#### Signature
```apex
public static CHILD_CONTACT_RECORD_TYPE
```

#### Type
string

## Methods
### `generateTestAttendanceData(businessLicenseId, numAccounts, numContactsPerAccount)`

Creates a &#x27;testing harness&#x27; for the attendance tracking functionality. Creates a businessLicense (if the businessLicenseId is passed in as null), 
accounts, contacts, enrollments, and attendance records.

#### Signature
```apex
public static map<string,list<sObject>> generateTestAttendanceData(id businessLicenseId, integer numAccounts, integer numContactsPerAccount)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| businessLicenseId | id | Id of the BusinessLicenseId record to attach enrollments to. Leave as null to automatically generate a new businessLicense |
| numAccounts | integer | Number of test accounts to create |
| numContactsPerAccount | integer | Number of contacts to create per account |

#### Return Type
**map&lt;string,list&lt;sObject&gt;&gt;**

a map containing keys for BusinessLicense,Accounts,Contacts, and Enrollment which will contain lists of the created records

---

### `enableCommunityUsers(contactIds, portalName)`

`FUTURE`

#### Signature
```apex
public static void enableCommunityUsers(Set<Id> contactIds, String portalName)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| contactIds | Set&lt;Id&gt; |  |
| portalName | String |  |

#### Return Type
**void**

---

### `getAllEnrolleesForLicense(businessLicenseId, startDate, endDate)`

Generates a mock importable attendance CSV file that can be used for testing/demos. Generates a random number of check in events between the min and 
max provided for each child with an active enrollment in the given business license id.

#### Signature
```apex
public static list<EnrollmentWrapper> getAllEnrolleesForLicense(id businessLicenseId, Date startDate, Date endDate)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| businessLicenseId | id |  |
| startDate | Date |  |
| endDate | Date |  |

#### Return Type
**list&lt;EnrollmentWrapper&gt;**

---

### `getAllEnrolleesForLicense(businessLicenseId, startDate, endDate, householdId)`

#### Signature
```apex
public static list<EnrollmentWrapper> getAllEnrolleesForLicense(id businessLicenseId, Date startDate, Date endDate, id householdId)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| businessLicenseId | id |  |
| startDate | Date |  |
| endDate | Date |  |
| householdId | id |  |

#### Return Type
**list&lt;EnrollmentWrapper&gt;**

---

### `getAttendanceRoster(businessLicenseId, rosterDate)`

Gets all existing Attendance records and temporary placeholders for those that do not exist which may then be upserted

#### Signature
```apex
public static RosterWrapper getAttendanceRoster(Id businessLicenseId, Date rosterDate)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| businessLicenseId | Id | Id of the business license to find all enrollments for |
| rosterDate | Date | the date for which to find the attendance roster |

#### Return Type
**RosterWrapper**

A list of EnrollmentWrappers that contain the enrollment__c records

---

### `getAttendanceRoster(businessLicenseId, rosterDate, householdId)`

#### Signature
```apex
public static RosterWrapper getAttendanceRoster(Id businessLicenseId, Date rosterDate, Id householdId)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| businessLicenseId | Id |  |
| rosterDate | Date |  |
| householdId | Id |  |

#### Return Type
**RosterWrapper**

---

### `getParentContactsByAccount(businessLicenseId)`

`AURAENABLED`

#### Signature
```apex
public static Map<Id,List<Contact>> getParentContactsByAccount(String businessLicenseId)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| businessLicenseId | String |  |

#### Return Type
**Map&lt;Id,List&lt;Contact&gt;&gt;**

---

### `getBusinessLicenseIntegration(businessLicenseId, forDate)`

Retrieves a `Business_License_Integration_Tracker__c` record based on the provided business license ID and a specified date. 
This method only returns a `Business_License_Integration_Tracker__c` record if there is at least one related 
 `BL_Integration_Tracker_History__c` record meeting the specified date criteria. 
 
This function performs a SOQL query to obtain details of a `Business_License_Integration_Tracker__c` record 
along with its related `BL_Integration_Tracker_History__c` records. The retrieved record will include: 
- Name 
- Last_Integration_Time__c 
- Start_Date__c 
- Vendor_Integration__c 
Additionally, the query returns related `BL_Integration_Tracker_History__c` records that have a `Start_Date__c` 
less than or equal to the given date ( `forDate` ) and either: 
1. An `End_Date__c` greater than or equal to `forDate` , or 
2. A null `End_Date__c` . 
 
Only `Business_License_Integration_Tracker__c` records that have at least one matching `BL_Integration_Tracker_History__c` 
record as per the date criteria will be returned. If no record meets the criteria, an empty `Business_License_Integration_Tracker__c` 
object is returned.

#### Signature
```apex
public static Business_License_Integration_Tracker__c getBusinessLicenseIntegration(Id businessLicenseId, date forDate)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| businessLicenseId | Id | The unique identifier ( `Id` ) of the `Business_License__c` to retrieve the associated 
 `Business_License_Integration_Tracker__c` record. |
| forDate | date | The date ( `Date` ) against which related `BL_Integration_Tracker_History__c` records are filtered. 
Only history records with `Start_Date__c` on or before this date and with `End_Date__c` 
on or after this date (or null) will be included. |

#### Return Type
**Business_License_Integration_Tracker__c**

A ,[object Object], record with its related ,[object Object], records,[object Object],        if one or more history records match the date conditions. Returns an empty ,[object Object],[object Object],        object if no records meet the criteria.

---

### `setCheckedInStatus(attendanceData)`

Updates the Attendance__c record of an attendeeWrapper. If the attendeeWrapper.checkedIn flag is set to true the First_Check_In__c (Datetime), Is_Checked_In__c (Boolean), 
and Checked_In_By__c (User Lookup) will be populated. If not, the Last_Checkout__c, Is_Checked_Out__c and Checked_Out_By__c fields will be set. The DML operation on the attendance record 
is an upsert so it can handle new or existing attendance__c records.

#### Signature
```apex
public static list<AttendeeWrapper> setCheckedInStatus(list<AttendanceUtilities.AttendeeWrapper> attendanceData)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| attendanceData | list&lt;AttendanceUtilities.AttendeeWrapper&gt; | list of AttendanceUtilities.AttendeeWrapper records that contain the checkedIn property set to true or false. |

#### Return Type
**list&lt;AttendeeWrapper&gt;**

a list of AttendeeWrapper objects that contain the updated status

---

### `generateAttendanceRecords(businessLicenseId, effectiveDate, allOrNothingDML)`

Creates container Attendance__c records for all the valid enrollments in a given businessLicense Id for a given date.

#### Signature
```apex
public static list<Attendance__c> generateAttendanceRecords(Id businessLicenseId, Date effectiveDate, boolean allOrNothingDML)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| businessLicenseId | Id | The Id of the business license to create attendance records for |
| effectiveDate | Date | The date to create the attendance records for |
| allOrNothingDML | boolean | Should the DML operation to create the attendance__c records be all or nothing? |

#### Return Type
**list&lt;Attendance__c&gt;**

list of created Attendance__c records

---

### `generateAttendanceRecords(businessLicenseId, effectiveDate, allOrNothingDML, householdId)`

#### Signature
```apex
public static list<Attendance__c> generateAttendanceRecords(Id businessLicenseId, Date effectiveDate, boolean allOrNothingDML, id householdId)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| businessLicenseId | Id |  |
| effectiveDate | Date |  |
| allOrNothingDML | boolean |  |
| householdId | id |  |

#### Return Type
**list&lt;Attendance__c&gt;**

---

### `getAttendanceTrackingData(attendanceRecordId)`

Gets all the attendance_tracking__c records for a given attendance__c record id in a container object that also contains information about the 
attendance__c record and the related contact__ record

#### Signature
```apex
public static AttendanceTrackingWrapperContainer getAttendanceTrackingData(id attendanceRecordId)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| attendanceRecordId | id | Id of parent attendance__c record to fetch attendance_tracking__c records for |

#### Return Type
**AttendanceTrackingWrapperContainer**

AttendanceTrackingWrapperContainer a container wrapper object containing information about the attendance__c record, contact and tracking__c records.,[object Object],properties come back defined but empty if no matching attendance__c is found.

---

### `shareAttendanceForBusinessLicenseRoles(blRoleIds)`

`FUTURE`

Gets all users related to a given business license record through BusinessLicenseRole records. The  BusinessLicenseRole must be set to isActive__c &#x3D; true

#### Signature
```apex
public static void shareAttendanceForBusinessLicenseRoles(set<Id> blRoleIds)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| blRoleIds | set&lt;Id&gt; |  |

#### Return Type
**void**

map of business license it to all users related to the business license via a BusinessLicenseRole junction record that is active.

---

### `shareAttendanceForBusinessLicenseRoles(blRoles)`

Creates Attendance__Share records to share Attendance__c records related to a BusinessLicense with the Users in the given Business_License_Role__c records.

#### Signature
```apex
public static list<AttendanceUtilities.ShareRequestResult> shareAttendanceForBusinessLicenseRoles(map<Id,Business_License_Role__c> blRoles)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| blRoles | map&lt;Id,Business_License_Role__c&gt; | A map of Business_License_Role__c record ids to evaluate and grant access to Attendance__c records for. The records in the map must have the User__c, Attendance__c, and Provider_Hub_Access_Level__c field populated. |

#### Return Type
**list&lt;AttendanceUtilities.ShareRequestResult&gt;**

A list of sharing request results that contain the results of the sharing operation.

---

### `getAccessLevelFromBusinessLicenseRole(thisRole)`

#### Signature
```apex
public static string getAccessLevelFromBusinessLicenseRole(Business_License_Role__c thisRole)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| thisRole | Business_License_Role__c |  |

#### Return Type
**string**

---

### `setAttendanceTrackingStatus(attendanceData, allOrNothingDML)`

Creates Apex sharing records for the given shareTargets with the given accessLevel to all the records in the list of record Ids provided. Can create 
multiple types of shares for different objects in one invocation.

#### Signature
```apex
private static list<AttendanceTrackingResultWrapper> setAttendanceTrackingStatus(list<AttendanceUtilities.AttendeeWrapper> attendanceData, boolean allOrNothingDML)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| attendanceData | list&lt;AttendanceUtilities.AttendeeWrapper&gt; |  |
| allOrNothingDML | boolean |  |

#### Return Type
**list&lt;AttendanceTrackingResultWrapper&gt;**

a list of the results of creation of the share records. Contains information about the success of the share creation, error messages, and related record info.

---

### `createBusinessLicenseRoles(businessLicenseId, userIds)`

Creates Business_License_Role__c for the given BusinessLicense for the given userIds

#### Signature
```apex
public static list<Business_License_Role__c> createBusinessLicenseRoles(id businessLicenseId, set<Id> userIds)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| businessLicenseId | id | Id of businessLicense record to create roles for. |
| userIds | set&lt;Id&gt; | set of ids to make roles for. |

#### Return Type
**list&lt;Business_License_Role__c&gt;**

list of created businessLicenseRole

---

### `getAttendeeWrappersFromRecords(attendanceRecordIds)`

gets a list of attendeeWrapper objects for a given list of attendance__c record ids.

#### Signature
```apex
private static list<AttendeeWrapper> getAttendeeWrappersFromRecords(list<Id> attendanceRecordIds)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| attendanceRecordIds | list&lt;Id&gt; | list of ids of attendance__c record ids for which to generate AttendeeWrapper records |

#### Return Type
**list&lt;AttendeeWrapper&gt;**

list of AttendeeWrapper objects that contain all information about attendance and related tracking records needed to build tables/etc

---

### `handleError(e)`

generic error handler. Logs the error to the console. May later be hooked up to org wide error handler to log via platform event

#### Signature
```apex
public static void handleError(Exception e)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| e | Exception | exception to log |

#### Return Type
**void**

void

---

### `generatePin(contactId)`

this method is to generate a PIN for a Parent when triggered from the experience site

#### Signature
```apex
public static void generatePin(Id contactId)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| contactId | Id | contactToUpdate |

#### Return Type
**void**

void

---

### `findDuplicatesChildren(childRecordsString, businessLicenseId)`

#### Signature
```apex
public static Object findDuplicatesChildren(String childRecordsString, String businessLicenseId)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| childRecordsString | String |  |
| businessLicenseId | String |  |

#### Return Type
**Object**

---

### `findDuplicatesConstituents(constituentsRecordsString, businessLicenseId, constituentType)`

#### Signature
```apex
public static Object findDuplicatesConstituents(String constituentsRecordsString, String businessLicenseId, String constituentType)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| constituentsRecordsString | String |  |
| businessLicenseId | String |  |
| constituentType | String |  |

#### Return Type
**Object**

---

### `updateExistingEnrollment(childRecordsString, businessLicenseId, duplicatesSelectedString)`

#### Signature
```apex
public static Object updateExistingEnrollment(String childRecordsString, String businessLicenseId, String duplicatesSelectedString)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| childRecordsString | String |  |
| businessLicenseId | String |  |
| duplicatesSelectedString | String |  |

#### Return Type
**Object**

---

### `updateMapValuesWithList(mapToUpdate, updatedList)`

#### Signature
```apex
public static void updateMapValuesWithList(Map<String,SObject> mapToUpdate, List<SObject> updatedList)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| mapToUpdate | Map&lt;String,SObject&gt; |  |
| updatedList | List&lt;SObject&gt; |  |

#### Return Type
**void**

---

### `emailAddressIsValid(email)`

#### Signature
```apex
public static Boolean emailAddressIsValid(String email)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| email | String |  |

#### Return Type
**Boolean**

---

### `sanitizeInput(input)`

#### Signature
```apex
public static String sanitizeInput(String input)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| input | String |  |

#### Return Type
**String**

## Classes
### ShareRequestResult Class

Class for returning the results of a sharing record creation operation.

#### Fields
##### `success`

###### Signature
```apex
public success
```

###### Type
boolean

---

##### `shareRecord`

###### Signature
```apex
public shareRecord
```

###### Type
sObject

---

##### `message`

###### Signature
```apex
public message
```

###### Type
string

---

##### `recordObjectType`

###### Signature
```apex
public recordObjectType
```

###### Type
string

---

##### `sharedToType`

###### Signature
```apex
public sharedToType
```

###### Type
string

---

##### `sharedTo`

###### Signature
```apex
public sharedTo
```

###### Type
object

---

##### `record`

###### Signature
```apex
public record
```

###### Type
object

---

##### `shareCreated`

###### Signature
```apex
public shareCreated
```

###### Type
dateTime

---

##### `invokedBy`

###### Signature
```apex
public invokedBy
```

###### Type
string

---

##### `runningUser`

###### Signature
```apex
public runningUser
```

###### Type
user

#### Constructors
##### `ShareRequestResult(saveResult, shareRecord, sharedTo, record, runningUser)`

###### Signature
```apex
public ShareRequestResult(Database.SaveResult saveResult, sObject shareRecord, object sharedTo, object record, user runningUser)
```

###### Parameters
| Name | Type | Description |
|------|------|-------------|
| saveResult | Database.SaveResult |  |
| shareRecord | sObject |  |
| sharedTo | object |  |
| record | object |  |
| runningUser | user |  |

### RosterWrapper Class

Overall roster information that is returned to the attendance LWCs that contain the list of attendees, the applicable date, business license 
information and other relevant data to rostering/attendance.

#### Fields
##### `businessLicenseId`

`AURAENABLED`

###### Signature
```apex
public businessLicenseId
```

###### Type
id

---

##### `businessLicenseName`

`AURAENABLED`

###### Signature
```apex
public businessLicenseName
```

###### Type
string

---

##### `businessLicenseProgramName`

`AURAENABLED`

###### Signature
```apex
public businessLicenseProgramName
```

###### Type
string

---

##### `rosterDate`

`AURAENABLED`

###### Signature
```apex
public rosterDate
```

###### Type
date

---

##### `dateLabel`

`AURAENABLED`

###### Signature
```apex
public dateLabel
```

###### Type
string

---

##### `numAttendees`

`AURAENABLED`

###### Signature
```apex
public numAttendees
```

###### Type
integer

---

##### `numCheckedIn`

`AURAENABLED`

###### Signature
```apex
public numCheckedIn
```

###### Type
integer

---

##### `numCheckedOut`

`AURAENABLED`

###### Signature
```apex
public numCheckedOut
```

###### Type
integer

---

##### `dataSourceIsIntegration`

`AURAENABLED`

###### Signature
```apex
public dataSourceIsIntegration
```

###### Type
boolean

---

##### `dataIntegrationSourceName`

`AURAENABLED`

###### Signature
```apex
public dataIntegrationSourceName
```

###### Type
string

---

##### `businessLicenseIntegrationTracker`

`AURAENABLED`

###### Signature
```apex
public businessLicenseIntegrationTracker
```

###### Type
Business_License_Integration_Tracker__c

---

##### `dataIntegrationLastUpdate`

`AURAENABLED`

###### Signature
```apex
public dataIntegrationLastUpdate
```

###### Type
datetime

---

##### `attendees`

`AURAENABLED`

###### Signature
```apex
public attendees
```

###### Type
list&lt;AttendeeWrapper&gt;

#### Constructors
##### `RosterWrapper(businessLicenseId, rosterDate, Attendees)`

###### Signature
```apex
public RosterWrapper(Id businessLicenseId, Date rosterDate, list<AttendeeWrapper> Attendees)
```

###### Parameters
| Name | Type | Description |
|------|------|-------------|
| businessLicenseId | Id |  |
| rosterDate | Date |  |
| Attendees | list&lt;AttendeeWrapper&gt; |  |

### EnrollmentWrapper Class

Wrapper class for the Enrollment__c object. An enrollment connects a contact/student to a business.

#### Fields
##### `record`

`AURAENABLED`

###### Signature
```apex
public record
```

###### Type
Enrollment__c

#### Constructors
##### `EnrollmentWrapper(thisEnrollment)`

###### Signature
```apex
public EnrollmentWrapper(Enrollment__c thisEnrollment)
```

###### Parameters
| Name | Type | Description |
|------|------|-------------|
| thisEnrollment | Enrollment__c |  |

### AttendeeWrapper Class

Wrapper class that contains information relevant to attendance tracking. It&#x27;s a combination of an Attendance__c and Contact object containing information 
about the current check in status for that person for a given day.

#### Fields
##### `uniqueIdKey`

`AURAENABLED`

###### Signature
```apex
public uniqueIdKey
```

###### Type
string

---

##### `attendanceRecord`

`AURAENABLED`

###### Signature
```apex
public attendanceRecord
```

###### Type
Attendance__c

---

##### `attendeeRecord`

`AURAENABLED`

###### Signature
```apex
public attendeeRecord
```

###### Type
Contact

---

##### `isNew`

`AURAENABLED`

###### Signature
```apex
public isNew
```

###### Type
boolean

---

##### `firstName`

`AURAENABLED`

###### Signature
```apex
public firstName
```

###### Type
string

---

##### `lastName`

`AURAENABLED`

###### Signature
```apex
public lastName
```

###### Type
string

---

##### `birthDate`

`AURAENABLED`

###### Signature
```apex
public birthDate
```

###### Type
date

---

##### `checkedIn`

`AURAENABLED`

###### Signature
```apex
public checkedIn
```

###### Type
boolean

---

##### `checkedOut`

`AURAENABLED`

###### Signature
```apex
public checkedOut
```

###### Type
boolean

---

##### `checkedInTime`

`AURAENABLED`

###### Signature
```apex
public checkedInTime
```

###### Type
dateTime

---

##### `checkedOutTime`

`AURAENABLED`

###### Signature
```apex
public checkedOutTime
```

###### Type
dateTime

---

##### `checkedInBy`

`AURAENABLED`

###### Signature
```apex
public checkedInBy
```

###### Type
string

---

##### `checkedOutBy`

`AURAENABLED`

###### Signature
```apex
public checkedOutBy
```

###### Type
string

---

##### `numOpenCheckIns`

`AURAENABLED`

###### Signature
```apex
public numOpenCheckIns
```

###### Type
integer

---

##### `checkedInMinutes`

`AURAENABLED`

###### Signature
```apex
public checkedInMinutes
```

###### Type
integer

---

##### `totalCheckins`

`AURAENABLED`

###### Signature
```apex
public totalCheckins
```

###### Type
integer

---

##### `operatingContact`

`AURAENABLED`

###### Signature
```apex
public operatingContact
```

###### Type
id

---

##### `attendanceTrackingSaveResults`

`AURAENABLED`

###### Signature
```apex
public attendanceTrackingSaveResults
```

###### Type
list&lt;AttendanceTrackingResultWrapper&gt;

---

##### `parentsWithEmail`

`AURAENABLED`

###### Signature
```apex
public transient parentsWithEmail
```

###### Type
list&lt;Contact&gt;

---

##### `hasParentWithEmail`

`AURAENABLED`

###### Signature
```apex
public hasParentWithEmail
```

###### Type
boolean

---

##### `updatedCheckInTime`

`AURAENABLED`

###### Signature
```apex
public updatedCheckInTime
```

###### Type
dateTime

---

##### `updatedCheckOutTime`

`AURAENABLED`

###### Signature
```apex
public updatedCheckOutTime
```

###### Type
dateTime

---

##### `isOpen`

`AURAENABLED`

###### Signature
```apex
public isOpen
```

###### Type
boolean

#### Constructors
##### `AttendeeWrapper(thisContact, thisAttendance)`

###### Signature
```apex
public AttendeeWrapper(Contact thisContact, Attendance__c thisAttendance)
```

###### Parameters
| Name | Type | Description |
|------|------|-------------|
| thisContact | Contact |  |
| thisAttendance | Attendance__c |  |

---

##### `AttendeeWrapper()`

###### Signature
```apex
public AttendeeWrapper()
```

### AttendanceTrackingWrapperContainer Class

#### Fields
##### `attendanceRecord`

`AURAENABLED`

###### Signature
```apex
public attendanceRecord
```

###### Type
Attendance__c

---

##### `contact`

`AURAENABLED`

###### Signature
```apex
public contact
```

###### Type
Contact

---

##### `tracking`

`AURAENABLED`

###### Signature
```apex
public tracking
```

###### Type
list&lt;AttendanceTrackingWrapper&gt;

---

##### `allowDelete`

`AURAENABLED`

###### Signature
```apex
public allowDelete
```

###### Type
boolean

---

##### `allowUpdate`

`AURAENABLED`

###### Signature
```apex
public allowUpdate
```

###### Type
boolean

### AttendanceTrackingWrapper Class

#### Fields
##### `attendanceTrackingRecord`

`AURAENABLED`

###### Signature
```apex
public attendanceTrackingRecord
```

###### Type
Attendance_Tracking__c

---

##### `recordId`

`AURAENABLED`

###### Signature
```apex
public recordId
```

###### Type
Id

---

##### `Name`

`AURAENABLED`

###### Signature
```apex
public Name
```

###### Type
string

---

##### `checkedIn`

`AURAENABLED`

###### Signature
```apex
public checkedIn
```

###### Type
boolean

---

##### `checkedOut`

`AURAENABLED`

###### Signature
```apex
public checkedOut
```

###### Type
boolean

---

##### `checkedInTime`

`AURAENABLED`

###### Signature
```apex
public checkedInTime
```

###### Type
dateTime

---

##### `checkedOutTime`

`AURAENABLED`

###### Signature
```apex
public checkedOutTime
```

###### Type
dateTime

---

##### `checkedInBy`

`AURAENABLED`

###### Signature
```apex
public checkedInBy
```

###### Type
string

---

##### `checkedOutBy`

`AURAENABLED`

###### Signature
```apex
public checkedOutBy
```

###### Type
string

---

##### `numOpenCheckIns`

`AURAENABLED`

###### Signature
```apex
public numOpenCheckIns
```

###### Type
integer

---

##### `checkedInMinutes`

`AURAENABLED`

###### Signature
```apex
public checkedInMinutes
```

###### Type
integer

---

##### `preventUpdate`

`AURAENABLED`

###### Signature
```apex
public preventUpdate
```

###### Type
boolean

---

##### `preventDelete`

`AURAENABLED`

###### Signature
```apex
public preventDelete
```

###### Type
boolean

---

##### `isNew`

`AURAENABLED`

###### Signature
```apex
public isNew
```

###### Type
boolean

---

##### `dataSourceIsIntegration`

`AURAENABLED`

###### Signature
```apex
public dataSourceIsIntegration
```

###### Type
boolean

---

##### `dataIntegrationSourceName`

`AURAENABLED`

###### Signature
```apex
public dataIntegrationSourceName
```

###### Type
string

---

##### `dataIntegrationSourceId`

`AURAENABLED`

###### Signature
```apex
public dataIntegrationSourceId
```

###### Type
string

#### Constructors
##### `AttendanceTrackingWrapper(trackingRecord)`

###### Signature
```apex
public AttendanceTrackingWrapper(Attendance_Tracking__c trackingRecord)
```

###### Parameters
| Name | Type | Description |
|------|------|-------------|
| trackingRecord | Attendance_Tracking__c |  |

---

##### `AttendanceTrackingWrapper()`

###### Signature
```apex
public AttendanceTrackingWrapper()
```

### PinOperationResponse Class

#### Fields
##### `success`

`AURAENABLED`

###### Signature
```apex
public success
```

###### Type
boolean

---

##### `message`

`AURAENABLED`

###### Signature
```apex
public message
```

###### Type
string

---

##### `contact`

`AURAENABLED`

###### Signature
```apex
public contact
```

###### Type
Contact

---

##### `enrollments`

`AURAENABLED`

###### Signature
```apex
public enrollments
```

###### Type
list&lt;AttendanceUtilities.EnrollmentWrapper&gt;

---

##### `action`

`AURAENABLED`

###### Signature
```apex
public action
```

###### Type
string

---

##### `pinType`

`AURAENABLED`

###### Signature
```apex
public pinType
```

###### Type
string

#### Constructors
##### `PinOperationResponse(actionName)`

###### Signature
```apex
public PinOperationResponse(string actionName)
```

###### Parameters
| Name | Type | Description |
|------|------|-------------|
| actionName | string |  |

### ConstituentInformationWrapper Class

#### Fields
##### `guardianId`

`AURAENABLED`

###### Signature
```apex
public guardianId
```

###### Type
String

---

##### `trustedId`

`AURAENABLED`

###### Signature
```apex
public trustedId
```

###### Type
String

---

##### `guardianLastName`

`AURAENABLED`

###### Signature
```apex
public guardianLastName
```

###### Type
String

---

##### `guardianFirstName`

`AURAENABLED`

###### Signature
```apex
public guardianFirstName
```

###### Type
String

---

##### `trustedFirstName`

`AURAENABLED`

###### Signature
```apex
public trustedFirstName
```

###### Type
String

---

##### `trustedLastName`

`AURAENABLED`

###### Signature
```apex
public trustedLastName
```

###### Type
String

---

##### `ParentFullName`

`AURAENABLED`

###### Signature
```apex
public ParentFullName
```

###### Type
String

---

##### `TrustedFullName`

`AURAENABLED`

###### Signature
```apex
public TrustedFullName
```

###### Type
String

### ChildInformationWrapper Class

#### Fields
##### `childId`

`AURAENABLED`

###### Signature
```apex
public childId
```

###### Type
String

---

##### `childFirstName`

`AURAENABLED`

###### Signature
```apex
public childFirstName
```

###### Type
String

---

##### `childLastName`

`AURAENABLED`

###### Signature
```apex
public childLastName
```

###### Type
String

---

##### `childDateOfBirth`

`AURAENABLED`

###### Signature
```apex
public childDateOfBirth
```

###### Type
String

---

##### `ChildFullName`

`AURAENABLED`

###### Signature
```apex
public ChildFullName
```

###### Type
String

---

##### `childStartDate`

`AURAENABLED`

###### Signature
```apex
public childStartDate
```

###### Type
String

---

##### `childEndDate`

`AURAENABLED`

###### Signature
```apex
public childEndDate
```

###### Type
String

---

##### `childUniqueId`

`AURAENABLED`

###### Signature
```apex
public childUniqueId
```

###### Type
String

---

##### `enrollmentId`

`AURAENABLED`

###### Signature
```apex
public enrollmentId
```

###### Type
String

### DuplicateEntryWrapper Class

#### Fields
##### `name`

`AURAENABLED`

###### Signature
```apex
public name
```

###### Type
String

---

##### `uniqueId`

`AURAENABLED`

###### Signature
```apex
public uniqueId
```

###### Type
String

---

##### `duplicateEntries`

`AURAENABLED`

###### Signature
```apex
public duplicateEntries
```

###### Type
Map&lt;String,DuplicateContactWrapper&gt;

### DuplicateContactWrapper Class

#### Fields
##### `Id`

`AURAENABLED`

###### Signature
```apex
public Id
```

###### Type
String

---

##### `contactRecord`

`AURAENABLED`

###### Signature
```apex
public contactRecord
```

###### Type
Contact

---

##### `selected`

`AURAENABLED`

###### Signature
```apex
public selected
```

###### Type
Boolean

---

##### `householdInformation`

`AURAENABLED`

###### Signature
```apex
public householdInformation
```

###### Type
List&lt;HouseholdInformationWrapper&gt;

---

##### `enrollmentExpired`

`AURAENABLED`

###### Signature
```apex
public enrollmentExpired
```

###### Type
Boolean

---

##### `enrollmentPaused`

`AURAENABLED`

###### Signature
```apex
public enrollmentPaused
```

###### Type
Boolean

### HouseholdInformationWrapper Class

#### Fields
##### `householdName`

`AURAENABLED`

###### Signature
```apex
public householdName
```

###### Type
String

---

##### `householdDetails`

`AURAENABLED`

###### Signature
```apex
public householdDetails
```

###### Type
List&lt;Contact&gt;

### AttendanceTrackingResultWrapper Class

#### Properties
##### `trackingRecord`

`AURAENABLED`

###### Signature
```apex
public trackingRecord
```

###### Type
Attendance_Tracking__c

---

##### `isSuccess`

`AURAENABLED`

###### Signature
```apex
public isSuccess
```

###### Type
Boolean

---

##### `errorMessage`

`AURAENABLED`

###### Signature
```apex
public errorMessage
```

###### Type
String

---

##### `friendlyError`

`AURAENABLED`

###### Signature
```apex
public friendlyError
```

###### Type
String

#### Constructors
##### `AttendanceTrackingResultWrapper(trackingRecord, isSuccess, errorMessage)`

###### Signature
```apex
public AttendanceTrackingResultWrapper(Attendance_Tracking__c trackingRecord, Boolean isSuccess, String errorMessage)
```

###### Parameters
| Name | Type | Description |
|------|------|-------------|
| trackingRecord | Attendance_Tracking__c |  |
| isSuccess | Boolean |  |
| errorMessage | String |  |

### LogicException Class

### ApplicationException Class

### DataException Class