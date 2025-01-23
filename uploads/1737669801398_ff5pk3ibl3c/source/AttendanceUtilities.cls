/**
* @name AttendanceUtilities
* @group AttendanceRostering
* @description shared utilities used by features in the attendance tracking business unit. Includes functions for creating test data, getting daily rosters for businesses,
* performing checkin/checkout operations and more.
* NOTE: Currenly set to without sharing as the profile for the community user does not have full access to the Enrollment__c records that are required to operate this class.
* @author Slalom
* @date 1/17/2024
* @demo-one
*```
*    //Generate test check in data by creating a new business license, associated accounts, contacts, and attendance__c records
*
*    map<string,list<sObject>> testData = AttendanceUtilities.generateTestAttendanceData(null, 25, 1);
*    BusinessLicense thisLicense = testData.get('BusinessLicense')[0];
*    
*    //find all the enrollees in our business licence
*    list<AttendanceUtilities.EnrollmentWrapper> enrollees = AttendanceUtilities.getAllLicenseEnrollees(thisLicense.Id);
*
*    //get an attendance roster that will contain a placeholder attendance record for every enrollee 
*    AttendanceUtilities.RosterWrapper roster = AttendanceUtilities.getAttendanceRoster(thisLicense.Id, Date.today());
*
*    //set each of our attendees to being checked in
*    for(AttendanceUtilities.AttendeeWrapper thisAttendee : roster.attendees){
*        thisAttendee.checkedIn = true;
*    }
*
*    //update our attendance records
*    list<AttendanceUtilities.AttendeeWrapper> checkInResults = AttendanceUtilities.setCheckedInStatus(roster.attendees);
*
*    system.debug(JSON.serializePretty(checkInResults));
*```
* @demo-two
*```
*    //Generate Test Data for All Business Licenses that don't have any enrollments
*
*    list<BusinessLicense> bl = [SELECT Id, Name, (Select Id from Enrollments__r) from BusinessLicense where id in (Select Business_License__c From Enrollment__c)];
*
*    for(BusinessLicense thisBl : bl){
*        system.debug('\n\n\n------- ' + thisBl.Name + ' Has ' + thisBl.Enrollments__r.size() + ' Enrollments!');
*        if(thisBl.Enrollments__r.isEmpty()){
*            AttendanceUtilities.generateTestAttendanceData(thisBl.Id, 25, 1);
*        }
*    }
*```
*/



global without sharing class AttendanceUtilities {

    public static string CONTACT_PROGRAM_PARTICIPATION = 'Enrollment and Attendance';
    public static string CHILD_CONTACT_RECORD_TYPE = 'Child';

    /**
    * @description Creates a 'testing harness' for the attendance tracking functionality. Creates a businessLicense (if the businessLicenseId is passed in as null),
    * accounts, contacts, enrollments, and attendance records.
    * @param businessLicenseId Id of the BusinessLicenseId record to attach enrollments to. Leave as null to automatically generate a new businessLicense
    * @param numAccounts Number of test accounts to create
    * @param numContactsPerAccount Number of contacts to create per account
    * @return a map containing keys for BusinessLicense,Accounts,Contacts, and Enrollment which will contain lists of the created records 
    */
    public static map<string,list<sObject>> generateTestAttendanceData(id businessLicenseId, integer numAccounts, integer numContactsPerAccount){

        Savepoint sp = Database.setSavePoint();
        map<string,list<sObject>> returnData = new map<string,list<sObject>>();
        try{
            system.debug('\n\n---INSIDE generateTestAttendanceData');
            //account record type 
            RecordType accRecordType = [select id, name from RecordType where sObjectType = 'Account' and developerName = 'Household'];

            RecordType childConRecordType = [select id, name from RecordType where sObjectType = 'Contact' and developerName = 'Child'];
            RecordType parentConRecordType = [select id, name from RecordType where sObjectType = 'Contact' and developerName = 'Constituent'];

            //Build some random names
            List<String> bnames = new List<String>{
                'Goku', 'Naruto', 'Kirito', 'Link', 'Cloud', 'Sephiroth', 'Sora', 'Ryu',
                'Ken', 'Mario', 'Luigi', 'Sonic', 'Shadow', 'Dante', 'Vergil', 'Geralt',
                'Ezio', 'Altair', 'SolidSnake', 'BigBoss', 'Raiden', 'Kratos', 'Arthur',
                'Jin', 'Kazuya', 'Ragna', 'Sub-Zero', 'Scorpion', 'Luffy', 'Zoro',
                'Ace', 'Gon', 'Killua', 'Yusuke', 'Inuyasha', 'Shinji', 'Edward', 'Alphonse',
                'Riku', 'Natsu', 'Tidus', 'Siegfried', 'Auron', 'Vash', 'Spike', 'Saitama',
                'Levi', 'Sasuke', 'Simon', 'Soma', 'Light', 'Ryuuk', 'Kuwabara', 'Hiei',
                'Kurama', 'Kenji', 'Kenshin', 'Harry', 'Ron', 'Aragorn', 'Legolas', 'Gimli',
                'Boromir', 'Frodo', 'Samwise', 'Eomer', 'Gandalf', 'Thorin', 'Dwalin', 'Balin',
                'Bilbo', 'Eddard', 'Jon', 'Tyrion', 'Jaime', 'Theon', 'Robb', 'Bran', 'Khal',
                'Luke', 'Anakin', 'Obi-Wan', 'Yoda', 'Palpatine', 'Han', 'Lando', 'Mace',
                'Qui-Gon', 'Garrus', 'Thane', 'Shepard', 'Alucard', 'Trevor', 'Richter', 'Simon',
                'Isaac', 'Hector', 'Hugh', 'Isaac Clarke', 'Gordon Freeman', 'Doomguy', 'Marcus',
                'Dom', 'Cole', 'Baird', 'Vander', 'Silco', 'Darius', 'Draven', 'Yasuo', 'Zed',
                'Aatrox', 'Ryze', 'Malzahar'
            };

            List<String> fnames = new List<String>{
                'Asuna', 'Hinata', 'Sakura', 'Serah', 'Tifa', 'Aerith', 'Yuna', 'Rinoa',
                'Zelda', 'Peach', 'Samus', 'Lucina', 'Jill', 'Claire', 'Ada', 'Ciri',
                'Triss', 'Yennefer', 'Bayonetta', 'Lara', 'Elena', 'Noel', 'Aqua',
                'Kairi', 'Rin', 'Rei', 'Mikasa', 'Botan', 'Keiko', 'Tomoe', 'Kaoru',
                'Ryuko', 'Homura', 'Maka', 'Elizabeth', 'Rem', 'Ram', 'Tsubasa', 'Lucy',
                'Erza', 'Nami', 'Boa', 'Misty', 'Serena', 'Cynthia', 'Lulu', 'Fran',
                'Kasumi', 'Shion', 'Mai', 'Chun-Li', 'Yoko', 'Nia', 'Erina', 'Misa',
                'Alice', 'Shanoa', 'Sophitia', 'Talim', 'Yuffie', 'Rikku', 'Aeris',
                'Fiona', 'Shiva', 'Freya', 'Beatrix', 'Terra', 'Selphie', 'Ellie',
                'Abby', 'Ellie', 'Sarah', 'Jaina', 'Sylvanas', 'Tyrande',
                'Katarina', 'Ahri', 'Sona', 'Vi', 'Jinx', 'Caitlyn', 'Edelgard', 'Dorothea',
                'Byleth', 'Eirika', 'Mythra', 'Pyra', 'Midna', 'Impa', 'Riju', 'Mipha',
                'Palutena', 'Rosalina', 'Tetra', 'Chell', 'Alyx', 'Morrigan', 'Isabela',
                'Leliana', 'Vivienne', 'Meredith', 'Merrill', 'Eevee', 'Froslass', 'Gardevoir'
            };

            List<String> lnames = new List<String>{
                'Kurosaki', 'Himura', 'Elric', 'Strife', 'Valentine', 'Ketchum',
                'Redfield', 'Aran', 'Belmont', 'Shepard', 'Kennedy', 'Croft',
                'Fisher', 'Morgan', 'Wright', 'Hawke', 'Fair', 'Vermillion',
                'Winchester', 'Drake', 'Fenix', 'Lockhart', 'Morrigan', 'Harkness',
                'Kenway', 'Vance', 'Parker', 'Hale', 'Price', 'Sparda',
                'Vickers', 'Williams', 'Burton', 'Everdeen', 'Grey', 'Walker',
                'Black', 'Stone', 'Maxwell', 'Vega', 'Hargreaves', 'Targaryen',
                'Stark', 'Wayne', 'Richter', 'Xanatos', 'Chambers', 'Blackwell',
                'Tepplin', 'Yukihira', 'Yagami', 'Ryuzaki', 'Kamado', 'Ackerman',
                'Zoldyck', 'Hellsing', 'Abarai', 'Satou', 'Kamui', 'Hinata',
                'Takahashi', 'Rengoku', 'Shinazugawa', 'Kaname', 'Shiba', 'Araragi',
                'Kisaragi', 'Lannister', 'Baratheon', 'Snow', 'Organa', 'Skywalker',
                'Solo', 'Kenobi', 'Palpatine', 'Tano', 'Djarin', 'Baggins',
                'Gamgee', 'Brandybuck', 'Took', 'Oakenshield', 'Durin', 'Boromir',
                'Faramir', 'Elessar', 'Granger', 'Malfoy', 'Weasley', 'Lovegood',
                'Dumbledore', 'Hagrid', 'Snape', 'Lestrange', 'Moody', 'Potter',
                'Blackfyre', 'Rutherford', 'Beleren', 'Garruk', 'Chandra'
            };
            list<string> allNames = new list<string>();
            allNames.addAll(bnames);
            allNames.addAll(fnames);

            // List of words related to child care and daycare
            List<String> prefixes = new List<String>{'Bright', 'Sunny', 'Happy', 'Little', 'Tiny', 'Creative', 'Smiling', 'Caring', 'Joyful', 'Magic'};
            List<String> suffixes = new List<String>{'Stars', 'Sprouts', 'Hearts', 'Kids', 'Adventures', 'Angels', 'Buddies', 'Dreamers', 'Nest', 'Garden'};
            
            // Randomly select words from the lists
            String prefix = prefixes[Math.floor(Math.random() * prefixes.size()).intValue()];
            String suffix = suffixes[Math.floor(Math.random() * suffixes.size()).intValue()];
            
            // Combine the selected words to create the daycare name
            String daycareName = prefix + ' ' + suffix + ' Daycare';

            if(businessLicenseId == null){
                //create a business license
                Integer licenseNumber = Math.round(Math.random() * 9000000) + 1000000;
                BusinessLicense thisLicense = new BusinessLicense(
                    Name = String.valueOf(licenseNumber),
                    Program_Name__c = daycareName + ' (TEST)', 
                    Generated_License_ID__c = licenseNumber,
                    DHS_Payments_Uploaded__c = false,
                    Do_Not_Issue_Flag__c = false,
                    Head_Start_Program__c = false,
                    IsActive = true,
                    isActive__c = true,
                    isEligibleForRenewal__c = true,
                    IsELSLegacyData__c = false,
                    isMigratedData__c = true,
                    isRenewalPaidCurrentPeriod__c = false,
                    Pending_Licensing_Action__c = false,
                    School_Based__c = true
                );
            

                insert thisLicense;
                businessLicenseId = thisLicense.Id;

                returnData.put('BusinessLicense',new list<BusinessLicense>{thisLicense});
            }else{
                returnData.put('BusinessLicense',new list<BusinessLicense>{new BusinessLicense(Id=businessLicenseId)});
            }

            /*
            Business_License_Role__c thisRole = new Business_License_Role__c();
            thisRole.User__c = UserInfo.getUserId();
            thisRole.Business_License__c = businessLicenseId;
            thisRole.isActive__c = true;
            thisRole.Provider_Hub_Access_Level__c = 'Delegated Authority'; 

            insert thisRole;
            */

            //generate accounts
            list<Account> accounts = new List<Account>();

            // Clone the lNames list to avoid modifying the original list
            List<String> availableNames = new List<String>(lNames);

            for (Integer i = 0; i < numAccounts; i++) {
                // Ensure there are still names left in the list
                if (availableNames.isEmpty()) {
                    throw new AuraHandledException('Not enough unique names in the list for the number of accounts requested.');
                }

                // Generate a random index from the available names
                Double randomNumber = Math.random();
                Integer randomIndex = (randomNumber * (availableNames.size())).intValue();

                // Create a new Account and assign values
                Account thisAccount = new Account();
                thisAccount.RecordTypeId = accRecordType.Id;
                thisAccount.Name = 'Test-' + availableNames[randomIndex];
                thisAccount.Phone = '123-1234-' +
                    Integer.valueOf(Math.random() * 9) + '' +
                    Integer.valueOf(Math.random() * 9) + '' +
                    Integer.valueOf(Math.random() * 9) + '' +
                    Integer.valueOf(Math.random() * 9);
                thisAccount.Business_License__c = businessLicenseId;

                // Add the Account to the list
                accounts.add(thisAccount);

                // Remove the used name from the availableNames list
                availableNames.remove(randomIndex);
            }

            insert accounts;
            returnData.put('Accounts',accounts);

            date min = date.today().addYears(-17);
            date max = date.today().addYears(-5);

            //generate our account contacts
            list<contact> contacts = new list<Contact>();
            list<contact> parentContacts = new list<Contact>();
            
            for(Account thisAccount : accounts){
                for(integer i =0; i < numContactsPerAccount; i++){
                    Contact thisContact = new Contact();
                    Double randomNumber = Math.random();
                    Integer randomIndex = (randomNumber *(allNames.size()-1)).intValue();
                    
                    thisContact.firstName = allNames[randomIndex];
                    thisContact.lastName = thisAccount.Name;
                    thisContact.AccountId = thisAccount.Id;
                    thisContact.recordTypeId = childConRecordType.Id;
                    thisContact.Status__c = 'Active';
                    thisContact.Program_Participation__c = CONTACT_PROGRAM_PARTICIPATION;
                    // Convert to DateTime values
                    DateTime mint = min, maxt = max.addDays(1);
                    // Then convert to milliseconds since Jan 1, 1970, and get difference in ms
                    Long minms = mint.getTime(), maxms = maxt.getTime(), diff = maxms - minms;
                    // Return a date between minms and maxms.
                    thisContact.birthdate = DateTime.newInstance(minms + Math.mod(Math.abs(Crypto.getRandomLong()), diff)).date();

                    contacts.add(thisContact);   


                }
                Double randomNumber = Math.random();
                Integer randomIndex = (randomNumber *(allNames.size()-1)).intValue();
                Contact parentContact = new Contact();
                //now we also want to create a parent for this account
                randomIndex = (randomNumber *(allNames.size()-1)).intValue();
                parentContact.firstname = allNames[randomIndex] + ' (PARENT)';
                parentContact.lastName = thisAccount.Name;
                parentContact.AccountId = thisAccount.Id;
                parentContact.Status__c = 'Active';
                parentContact.recordTypeId = parentConRecordType.Id;
                parentContact.RelationshipToChild__c = 'Parent';
                parentContact.Authorized_Adult__c = true;

                // Remove invalid characters from the first and last names
                String sanitizedFirstName = parentContact.firstname.replaceAll('[^a-zA-Z0-9]', '').toLowerCase(); // Remove anything non-alphanumeric
                String sanitizedLastName = parentContact.lastName.replaceAll('[^a-zA-Z0-9]', '').toLowerCase();   // Remove anything non-alphanumeric

                parentContact.email = sanitizedFirstName + '.' + sanitizedLastName + '@mn.us.dhs-test.com';
                parentContact.Birthdate = Date.today().addDays(-Math.floor(Math.random() * 25550).intValue() - 10950);

                parentContacts.add(parentContact);
            }

            insert contacts;
            insert parentContacts;
            
            List<Id> contactIds = new List<Id>(new Map<Id, Contact>(contacts).keySet());
            contacts = [SELECT firstname, lastname, AccountId, Status__c, Program_Participation__c, Unique_Identifier__c FROM Contact WHERE Id in :contactIds];

            returnData.put('Contacts',contacts);
            
            //create enrollments for our contacts for our business license
            list<Enrollment__c> enrollments = new list<Enrollment__c>();
            for(Contact thisContact : contacts){
                Enrollment__c thisEnrollment = new Enrollment__c();
                thisEnrollment.Business_License__c = businessLicenseId;
                thisEnrollment.Child__c = thisContact.Id;
                thisEnrollment.Start_Date__c = Date.today();
                //thisEnrollment.Termination_Date__c = thisEnrollment.Start_Date__c.addDays(365);
                thisEnrollment.Active__c = true;
                thisEnrollment.Name = 'Test Enrollment - ' + thisContact.firstName + ' ' + thisContact.lastName;
                thisEnrollment.Status__c = 'Enrolled';
                //thisEnrollment.Unique_Identifier__c = AttendanceBulkUploadController.generateEnrollmentUniqueId(thisContact, businessLicenseId);
                enrollments.add(thisEnrollment);
            }

            insert enrollments;
            returnData.put('Enrollments',enrollments);

            //Creating Community portal users

            Set<Id> portalContactIds = new Set<Id>();

            // Iterate through the contact list and add the IDs to the set
            for (Contact con : parentContacts) {
                if (con.Id != null) {
                    portalContactIds.add(con.Id);
                }
            }
            //if(!Test.isRunningTest()) enableCommunityUsers(portalContactIds, 'Provider Hub');
		}catch (Exception ex) {
            system.debug('\n\n---- EXCEPTION: ' + ex.getMessage() + ' ' + ex.getLineNumber());
            Database.rollback(sp);
            Logger.Instance.logErrorWithRT(ex, 'Getting the Error while calling generateTestAttendanceData', 'AttendanceUtilities','generateTestAttendanceData',Logger.LOG_TYPES.Attendance);
        }finally{
            Logger.Instance.push();
        }        
        return returnData;
    }

    @future
    public static void enableCommunityUsers(Set<Id> contactIds, String portalName) {
    
        String communityProfileName = 'Provider Hub Standard User';
    
        // Query contacts by IDs
        List<Contact> contacts = [SELECT Id, FirstName, LastName, Email, AccountId FROM Contact WHERE Id IN :contactIds];

        List<User> usersToCreate = new List<User>();
    
        // Get the community user profile
        Profile communityProfile = [SELECT Id FROM Profile WHERE Name = :communityProfileName LIMIT 1];
    
        // Loop through the contacts to create users for those not already enabled
        for (Contact con : contacts) {
            
            if (con.AccountId != null && con.Email != null) {
                try {
                    // Debug the contact info
    
                    // Create a new User associated with the Contact
                    User newUser = new User(
                        ContactId = con.Id,
                        Username = con.Email + '.' + DateTime.now().getTime(), // Ensure the email is unique by appending a timestamp
                        Email = con.Email,
                        LastName = con.LastName,
                        FirstName = con.FirstName,
                        Alias = con.FirstName.substring(0,1) + con.LastName.substring(0,4),
                        CommunityNickname = con.FirstName + con.LastName,
                        TimeZoneSidKey = 'America/Los_Angeles',
                        LocaleSidKey = 'en_US',
                        EmailEncodingKey = 'UTF-8',
                        LanguageLocaleKey = 'en_US',
                        ProfileId = communityProfile.Id,
                        IsActive = true
                    );
    
                    // Add the User to the list
                    usersToCreate.add(newUser);
    
                } catch (Exception e) {
                    System.debug('Failed to create user for contact: ' + con.Id + ' - ' + e.getMessage());
                }
            } else {
                System.debug('Skipping contact due to missing AccountId or Email. ContactId: ' + con.Id);
            }
        }
    
        // Insert all the new community users in bulk
        if (!usersToCreate.isEmpty()) {
            try {
                insert usersToCreate;
            } catch (DmlException e) {
                System.debug('Failed to insert users: ' + e.getMessage());
                System.debug('DML Error Details: ' + e.getDmlMessage(0));
            }
        } else {
            System.debug('No users to insert. Skipping DML operation.');
        }
    }

    /**
     * @description Generates a mock importable attendance CSV file that can be used for testing/demos. Generates a random number of check in events between the min and 
     * max provided for each child with an active enrollment in the given business license id.
     */
    // public static string generateMockAttendanceImportFile(id businessLicenseId, date startDate, date endDate, integer minCheckinsPerChild, integer maxCheckinsPerChild){
    //     //get all children enrolled in this program
        
    //     list<EnrollmentWrapper> enrollees = getAllEnrolleesForLicense(businessLicenseId, startDate, null);

    //     string headerRow = 'Child Id,Child First name,Child Last Name,Date of Birth,Time Checked in,Time Checked Out,RowNumber,Checked In By,Checked Out By';

    //     list<user> checkinUsers = [select id, firstname, lastname, username from user where profile.name = 'System Administrator'];

    //     list<string> rows = new list<string>();

    //     rows.add(headerRow);

    //     integer rowNum =0;
    //     Date iteratorDate = startDate;

    //     while(iteratorDate < endDate) {
    //         integer checkinYear = iteratorDate.year();
    //         integer checkinMonth = iteratorDate.month();
    //         integer checkinDay = iteratorDate.day();

    //         for(EnrollmentWrapper thisEnrollment : enrollees){
    //             Contact thisContact = thisEnrollment.record.Child__r;
    //             string birthDate = CSVImportEngine.convertValueFromSF(thisContact.birthdate, Schema.DisplayType.DATE);

    //             integer numCheckins =  Integer.valueof((Math.random() * maxCheckinsPerChild));

    //             integer lastHour = 1;

    //             for(integer checkinNum = 0; checkinNum < numCheckins; checkinNum++){
    //                 list<string> thisRow = new list<string>();

    //                 Integer checkinUserIndex = Integer.valueOf(checkinUsers.size()*Math.random());//
    //                 Integer checkoutUserIndex = Integer.valueOf(checkinUsers.size()*Math.random());//

    //                 string checkinUserText = checkinUsers[checkinUserIndex].username;
    //                 string checkoutUserText = checkinUsers[checkoutUserIndex].username;


    //                 integer thisCheckinHour = lastHour + Integer.valueof((Math.random() * 3)) +1;
    //                 integer thisCheckoutHour = thisCheckinHour + Integer.valueof((Math.random() * 3))+1;
    //                 integer thisCheckinMins = Integer.valueof((Math.random() * 60));
    //                 integer thisCheckoutMins = Integer.valueof((Math.random() * 60));

    //                 if(thisCheckinHour >= 24 || thisCheckoutHour >= 24){
    //                     system.debug('Checkin hour has exceeded number of hours in the day. Skipping');
    //                     continue;
    //                 }

    //                 string checkIn = CSVImportEngine.convertValueFromSF(Datetime.newInstance(checkinYear, checkinMonth, checkinDay, thisCheckinHour,thisCheckinMins,0), Schema.DisplayType.DATETIME);
    //                 string checkOut = CSVImportEngine.convertValueFromSF(Datetime.newInstance(checkinYear, checkinMonth, checkinDay, thisCheckoutHour,thisCheckoutMins,0), Schema.DisplayType.DATETIME);
                    
    //                 thisRow.addAll(new list<string>{thisContact.Unique_Identifier__c, thisContact.FirstName, thisContact.LastName,birthDate,checkIn,checkOut,String.valueOf(rowNum),checkinUserText,checkoutUserText});
    //                 rows.add(String.join(thisRow,','));
    //                 rowNum++;
    //             }

    //         }
    //         iteratorDate = iteratorDate.addDays(1);
    //     }

    //     string csvContent = String.join(rows,'\n');

    //     return csvContent;

    // }


    /**
    * @description Gets all unique enrollments for a given BusinessLicenseId within the given date range. endDate may be passed as null to find all active enrollments
    * @param businessLicenseId Id of the business license to find all enrollments for
    * @param startDate the earliest date to find active enrollments within
    * @param endDate optional. The latest date to find active enrollments within
    * @return A list of EnrollmentWrappers that contain the enrollment__c records
    */
    public static list<EnrollmentWrapper> getAllEnrolleesForLicense(id businessLicenseId, Date startDate, Date endDate){
        return getAllEnrolleesForLicense(businessLicenseId, startDate, endDate, null);
    }
    public static list<EnrollmentWrapper> getAllEnrolleesForLicense(id businessLicenseId, Date startDate, Date endDate, id householdId){
        list<EnrollmentWrapper> enrollees = new list<EnrollmentWrapper>();

        system.debug('\n\n\n---- Getting all enrollees with attendance records');
        system.debug('BusinessLicenseId: ' + BusinessLicenseId);
        system.debug('startDate: ' + startDate);
        system.debug('endDate: ' + endDate);
        list<Enrollment__c> enrollments = new list<Enrollment__c>();

        try {
            // Step 1: Run the initial query to find the most recently created valid enrollment for each child

            List<AggregateResult> enrollmentIds = [
                SELECT MAX(CreatedDate) maxCreatedDate, Child__r.Unique_Identifier__c, MAX(Id) maxId
                FROM Enrollment__c
                WHERE Business_License__c = :businessLicenseId
                AND Child__r.Program_Participation__c = :CONTACT_PROGRAM_PARTICIPATION
                AND Child__r.RecordType.Name = :CHILD_CONTACT_RECORD_TYPE
                AND Status__c = 'Enrolled'
                AND Start_Date__c <= :startDate 
                AND (End_Date__c > :endDate OR End_Date__c = null)
                AND Child__r.Unique_Identifier__c != null
                GROUP BY Child__r.Unique_Identifier__c
            ];

            // Extract Enrollment Ids into a list
            List<Id> enrollmentIdsList = new List<Id>();
            for (AggregateResult ar : enrollmentIds) {
                enrollmentIdsList.add((Id) ar.get('maxId'));
            }

            // Step 2: Now get the actual details about the enrollment records
            enrollments = [SELECT Id, 
                                                    Name, 
                                                    Program_Name__c,
                                                    Program_Parent_Aware_Rating__c,
                                                    Program_Type__c,
                                                    EnrollmentAward__c,
                                                    Child__r.Firstname, 
                                                    Child__r.Lastname,
                                                    Child__r.Account.Name,
                                                    Child__r.Birthdate,
                                                    Unique_Identifier__c,
                                                    Child__r.Unique_Identifier__c,

                                                    (SELECT Name,
                                                            First_Check_In__c,
                                                            Last_Checkout__c, 
                                                            Is_Checked_In__c,
                                                            Is_Checked_Out__c,
                                                            Enrollment__c,
                                                            Number_Of_Open_Checkins__c,
                                                            Total_Minutes__c,
                                                            Number_of_Check_in_Events__c,
                                                            Schedule_Date__c,
                                                            Unique_Identifier__c,
                                                            Has_Open_Check_In__c
                                                    FROM  Attendances__r
                                                    WHERE Schedule_Date__c = :startDate
                                                    LIMIT 1) 
                                            FROM Enrollment__c 
                                            WHERE Id IN :enrollmentIdsList
                                            ORDER BY Child__r.Firstname ASC, Start_Date__c DESC];

            //Logic to filter out enrollments where the childs household does not have an authorized adult. Sadly a semi join won't work because those
            //only work when using an ID field as the select field.

            // Step 2: Collect account IDs
            Set<Id> accountIds = new Set<Id>();

            for (Enrollment__c enrollment : enrollments) {
                if (enrollment.Child__r != null && enrollment.Child__r.AccountId != null) {
                    accountIds.add(enrollment.Child__r.AccountId);
                }
            }

            // Step 3: Query accounts with authorized adults
            Set<Id> authorizedAccountIds = new Set<Id>();

            for (Contact contact : [SELECT AccountId FROM Contact WHERE AccountId IN :accountIds AND Authorized_Adult__c = TRUE]) {
                authorizedAccountIds.add(contact.AccountId);
            }

            // Step 4: Filter enrollments
            List<Enrollment__c> filteredEnrollments = new List<Enrollment__c>();

            for (Enrollment__c enrollment : enrollments) {
                if (authorizedAccountIds.contains(enrollment.Child__r.AccountId)) {
                    filteredEnrollments.add(enrollment);
                }
            }

            enrollments = filteredEnrollments;

            system.debug('\n\n\n----- Found ' + enrollments.size() + ' enrollment records');

            //After thinking through a few different ways to incorperate the household id filter in the query only if it is provided this approach
            //of evaluating the list after query seemed the cleanest to me. You could also use dynamic DML, or a different method, or two separate queries, or 
            //add a condition that says 'includes :allValidHouseholds' but then you'd have to pre-query to find valid households, built the list, and the where condition could
            //get very long. so in the end I decided on this approach but feel free to refactor.
            list<Enrollment__c> validEnrollments = new list<Enrollment__c>();
            set<string> seenUniqueIds = new set<string>();

            //there theoretically should never be duplicate unique ids but if it does happen it will break everything down the line. So for now the best
            //thing we can do is ensure there are no duplicates in the list.
            for(Enrollment__c thisEnrollment : enrollments){

                //check to see if we have seen this id before.
                if(seenUniqueIds.contains(thisEnrollment.Child__r.Unique_Identifier__c)) {
                    system.debug('\n\n\n----- Warning duplicate contact unique Id detected "'+thisEnrollment.Child__r.Unique_Identifier__c+'"(Unique_Identifier__c) for contact ' + thisEnrollment.Child__r.Id + '. Skipping this child');
                    continue;

                }else{
                    //if we are not filtering via a household id to match, or if the accountId of the child matches the household id, then add this to our list
                    if(householdId == null || thisEnrollment.Child__r.AccountId == householdId){
                        validEnrollments.add(thisEnrollment);
                    }
                    
                }
                seenUniqueIds.add(thisEnrollment.Child__r.Unique_Identifier__c);
            }

            system.debug('\n\n\n -------- There were ' + validEnrollments.size() + ' of ' + enrollments.size() + ' valid enrollments');

            for(Enrollment__c thisEnrollment : validEnrollments){
                if(thisEnrollment.Attendances__r.isEmpty()) system.debug(thisEnrollment.Child__r.Firstname + ' ' + thisEnrollment.Child__r.Lastname + ' does not have an attendance record for this date ' );
                else system.debug(thisEnrollment.Child__r.Firstname + ' ' + thisEnrollment.Child__r.Lastname + ' has an attendance record for this date!' );
            }
            set<Id> contactIds = new set<Id>();
            for(Enrollment__c thisEnrollment : validEnrollments){
                //don't include duplicate enrollment records
                if(!contactIds.contains(thisEnrollment.Child__c)) enrollees.add(new EnrollmentWrapper(thisEnrollment));
                contactIds.add(thisEnrollment.Child__c);
            }
        }catch (Exception ex) {
            system.debug('\n\n\n----- Error!');
            system.debug(ex.getMessage() + ' on line ' + ex.getLineNumber());
            Logger.Instance.logErrorWithRT(ex, 'Getting the Error while calling getAllEnrolleesForLicense', 'AttendanceUtilities','getAllEnrolleesForLicense',Logger.LOG_TYPES.Attendance);
        	return null;
        }finally{
            Logger.Instance.push();
        }

        system.debug('\n\n\n -------- Returning ' + enrollees.size() + ' enrollee records generated from ' + enrollments.size() + ' found enrollments');
        return enrollees;
    }

    /**
    * @description Gets all existing Attendance records and temporary placeholders for those that do not exist which may then be upserted
    * @param BusinessLicenseId Id of the business license to find all enrollments for
    * @param rosterDate the date for which to find the attendance roster
    * @return A list of EnrollmentWrappers that contain the enrollment__c records
    */
    public static RosterWrapper getAttendanceRoster(Id businessLicenseId, Date rosterDate){
        return getAttendanceRoster(businessLicenseId, rosterDate, null);
    }
    public static RosterWrapper getAttendanceRoster(Id businessLicenseId, Date rosterDate, Id householdId){
        RosterWrapper roster;
        try {
            //ensure the attendance__c records exist for this businessLicense for this day. 
            list<Attendance__c> attendanceRecords = generateAttendanceRecords(businessLicenseId, rosterDate, true, householdId);

            system.debug('\n\n\n----- Getting enrollees for businessLicenseId: ' + businessLicenseId + ' in household: ' + householdId);
            //first find everyone who is enrolled under this license
            list<EnrollmentWrapper> enrollees = getAllEnrolleesForLicense(businessLicenseId, rosterDate, rosterDate, householdId);

            list<AttendeeWrapper> attendeeWrappers = new list<AttendeeWrapper>();

            //TODO: Add logic here to select all Trust_Adult__c contacts from each household and return them in a list in the AttendeeWrapper. This will be used
            //to find which if any adults have populated email address values. This should also set a boolean value on te AttendeeWrapper that indicates if there are no Trusted adults
            //with an email, which will then cause an error state in the data table.
            map<Id,Id> enrollmentIdToAccountIdMap = new map<Id,Id>();
            map<Id,List<Contact>> accoutIdToTrustedAdultContactMap = new map<Id,List<Contact>>();
            for(EnrollmentWrapper thisWrapper : enrollees){
                enrollmentIdToAccountIdMap.put(thisWrapper.record.Id, thisWrapper.record.Child__r.AccountId);
            }

            Map<Id, List<Contact>> accountIdToParentWithEmailMap = getParentContactsByAccount(businessLicenseId);


            //create AttendeeWrapper for each enrollment attendee
            for(EnrollmentWrapper thisEnrollment : enrollees){
                try{
                    AttendeeWrapper thisWrapper = new AttendeeWrapper(thisEnrollment.record.Child__r, thisEnrollment.record.Attendances__r[0]);

                    thisWrapper.parentsWithEmail = accountIdToParentWithEmailMap.containsKey(thisEnrollment.record.Child__r.AccountId) ? accountIdToParentWithEmailMap.get(thisEnrollment.record.Child__r.AccountId) : new list<Contact>();
                    thisWrapper.hasParentWithEmail = !thisWrapper.parentsWithEmail.isEmpty();

                    attendeeWrappers.add(thisWrapper);   
                }catch(exception ex){
                    system.debug('\n\n\n----- Error Constructing AttendeeWrapper For: ' + thisEnrollment.record.Child__r.Firstname + ' ' + thisEnrollment.record.Child__r.Lastname);
                    system.debug(ex.getMessage() + ' on line ' + ex.getLineNumber());
                    system.debug(ex.getStackTraceString());
                }
            }

            roster = new RosterWrapper(businessLicenseId, rosterDate, attendeeWrappers);
            list<BusinessLicense> thisLicense = [SELECT Name, Program_Name__c from BusinessLicense WHERE Id = :businessLicenseId LIMIT 1];
            if(!thisLicense.isEmpty()){
                roster.businessLicenseName = thisLicense[0].Name;
                roster.businessLicenseProgramName = thisLicense[0].Program_Name__c;
            }else{
                roster.businessLicenseName = 'Unknown License: ' + businessLicenseId;
            }

            Business_License_Integration_Tracker__c BLIT = getBusinessLicenseIntegration(businessLicenseId, rosterDate);
            roster.businessLicenseIntegrationTracker = BLIT;
            roster.dataIntegrationSourceName = BLIT?.Vendor_Name__c != null ? BLIT?.Vendor_Name__c : 'Unknown';
            roster.dataIntegrationLastUpdate = BLIT?.Last_Integration_Time__c != null ? BLIT?.Last_Integration_Time__c : null;
            roster.dataSourceIsIntegration = BLIT?.Id != null ? true : false;
            

        }catch (Exception ex) {
            system.debug('\n\n\n--- Error!');
            system.debug(ex.getMessage() + ' on line ' + ex.getLineNumber());
            system.debug(ex.getStackTraceString());
            Logger.Instance.logErrorWithRT(ex, 'Getting the Error while calling getAttendanceRoster', 'AttendanceUtilities','getAttendanceRoster',Logger.LOG_TYPES.Attendance);
        	return null;
        }finally{
            Logger.Instance.push();
        }
        return roster;
    }

    @AuraEnabled(cacheable=true)
    public static Map<Id, List<Contact>> getParentContactsByAccount(String businessLicenseId) {
        // Validate the input
        if (String.isBlank(businessLicenseId)) {
            throw new AuraHandledException('Business License ID is required.');
        }

        // Retrieve the "Constituent" RecordTypeId for Contacts
        Id constituentRecordTypeId = [
            SELECT Id FROM RecordType 
            WHERE SObjectType = 'Contact' AND DeveloperName = 'Constituent' 
            LIMIT 1
        ].Id;

        // Query Contacts with AccountContactRelations subquery
        Map<Id, List<Contact>> accountContactsMap = new Map<Id, List<Contact>>();
        List<Contact> contacts = [
            SELECT Id, AccountId, Email,
                   (SELECT Id FROM AccountContactRelations WHERE Contact.RelationshipToChild__c ='Parent')
            FROM Contact
            WHERE Account.Business_License__c = :businessLicenseId
            AND RecordTypeId = :constituentRecordTypeId
            AND Email != null
        ];

        // Filter contacts with at least one AccountContactRelation where Role is "Parent" and organize them into a map
        for (Contact contact : contacts) {
            if (!contact.AccountContactRelations.isEmpty()) {
                if (!accountContactsMap.containsKey(contact.AccountId)) {
                    accountContactsMap.put(contact.AccountId, new List<Contact>());
                }
                accountContactsMap.get(contact.AccountId).add(contact);
            }
        }

        return accountContactsMap;
    }

    /**
    * Retrieves a `Business_License_Integration_Tracker__c` record based on the provided business license ID and a specified date.
    * This method only returns a `Business_License_Integration_Tracker__c` record if there is at least one related 
    * `BL_Integration_Tracker_History__c` record meeting the specified date criteria.
    * 
    * This function performs a SOQL query to obtain details of a `Business_License_Integration_Tracker__c` record 
    * along with its related `BL_Integration_Tracker_History__c` records. The retrieved record will include:
    * - Name
    * - Last_Integration_Time__c
    * - Start_Date__c
    * - Vendor_Integration__c
    * Additionally, the query returns related `BL_Integration_Tracker_History__c` records that have a `Start_Date__c` 
    * less than or equal to the given date (`forDate`) and either:
    *   1. An `End_Date__c` greater than or equal to `forDate`, or
    *   2. A null `End_Date__c`.
    * 
    * Only `Business_License_Integration_Tracker__c` records that have at least one matching `BL_Integration_Tracker_History__c`
    * record as per the date criteria will be returned. If no record meets the criteria, an empty `Business_License_Integration_Tracker__c`
    * object is returned.
    *
    * @param businessLicenseId The unique identifier (`Id`) of the `Business_License__c` to retrieve the associated
    *                          `Business_License_Integration_Tracker__c` record.
    * @param forDate           The date (`Date`) against which related `BL_Integration_Tracker_History__c` records are filtered.
    *                          Only history records with `Start_Date__c` on or before this date and with `End_Date__c` 
    *                          on or after this date (or null) will be included.
    * @return A `Business_License_Integration_Tracker__c` record with its related `BL_Integration_Tracker_History__c` records 
    *         if one or more history records match the date conditions. Returns an empty `Business_License_Integration_Tracker__c`
    *         object if no records meet the criteria.
    */
    public static Business_License_Integration_Tracker__c getBusinessLicenseIntegration(Id businessLicenseId, date forDate){
        List<Business_License_Integration_Tracker__c> BLIT = [SELECT    Name,
                                                                        Last_Integration_Time__c,
                                                                        Start_Date__c,
                                                                        Vendor_Integration__c,
                                                                        Vendor_Name__c,
                                                                        (SELECT Active__c,
                                                                                Start_Date__c,
                                                                                End_Date__c,
                                                                                Vendor_Integration__c
                                                                        FROM BL_Integration_Tracker_Histories__r
                                                                        WHERE Start_Date__c <= :forDate 
                                                                        AND (End_Date__c >= :forDate OR End_Date__c = null))
                                                                FROM Business_License_Integration_Tracker__c
                                                                WHERE Business_License__c = :businessLicenseId
                                                                AND Id IN (SELECT Business_License_Integration_Tracker__c 
                                                                            FROM BL_Integration_Tracker_History__c 
                                                                            WHERE Start_Date__c <= :forDate 
                                                                            AND (End_Date__c >= :forDate OR End_Date__c = null)
                                                                            AND Vendor_Integration__c = true)];
        if(!BLIT.isEmpty()) return BLIT[0];
        return new Business_License_Integration_Tracker__c();    
    }

    /**
    * @description Updates the Attendance__c record of an attendeeWrapper. If the attendeeWrapper.checkedIn flag is set to true the First_Check_In__c (Datetime), Is_Checked_In__c (Boolean),
    * and Checked_In_By__c (User Lookup) will be populated. If not, the Last_Checkout__c, Is_Checked_Out__c and Checked_Out_By__c fields will be set. The DML operation on the attendance record
    * is an upsert so it can handle new or existing attendance__c records.
    * @param attendanceData list of AttendanceUtilities.AttendeeWrapper records that contain the checkedIn property set to true or false.
    * @return a list of AttendeeWrapper objects that contain the updated status
    */
    public static list<AttendeeWrapper> setCheckedInStatus(list<AttendanceUtilities.AttendeeWrapper> attendanceData){
        list<AttendeeWrapper> updatedWrappers = new list<AttendeeWrapper>();
        try{

            system.debug('\n\n\n---- Setting checked in status for incoming records');
            system.debug(attendanceData);
            map<Id,AttendanceUtilities.AttendeeWrapper> attendanceDataByIdMap = new map<Id,AttendanceUtilities.AttendeeWrapper>();

            for(AttendeeWrapper thisWrapper : attendanceData){
                attendanceDataByIdMap.put(thisWrapper.attendanceRecord.Id,thisWrapper);
            }

            //set the updated status
            list<AttendanceTrackingResultWrapper> createResults = AttendanceUtilities.setAttendanceTrackingStatus(attendanceData, false);

            system.debug('\n\n\n---- Create Results');
            system.debug(JSON.serializePretty(createResults));

            //re-query for data to get formula fields, etc that are only updated on commit
            updatedWrappers = getAttendeeWrappersFromRecords(new list<id>(attendanceDataByIdMap.keySet()));

            system.debug('\n\n\n---- Updated Wrappers');
            system.debug(JSON.serializePretty(updatedWrappers));

            //populate the save results of each tracking record save operation to the correct wrapper.

            system.debug('\n\n\n---- Attempting to write Attendance tracking save results back to wrappers');

            for(AttendeeWrapper thisWrapper : updatedWrappers){
                for(AttendanceTrackingResultWrapper thisSaveResult : createResults){
                    system.debug('\n\n\n----- Comparing: ' + thisWrapper.attendanceRecord.Id + ' TO ' + thisSaveResult.trackingRecord.Attendance__c);
                    if(thisWrapper.attendanceRecord.Id == thisSaveResult.trackingRecord.Attendance__c){
                        system.debug('\n\n\n----- MATCH FOUND!');
                        thisWrapper.attendanceTrackingSaveResults.add(thisSaveResult);
                    }
                }

            }
        }catch (Exception ex) {
            Logger.Instance.logErrorWithRT(ex, 'Getting the Error while calling setCheckedInStatus', 'AttendanceUtilities','setCheckedInStatus',Logger.LOG_TYPES.Attendance);
        	return null;
        }finally{
            Logger.Instance.push();
        }
        return updatedWrappers;

    }

    /**
    * @description Creates container Attendance__c records for all the valid enrollments in a given businessLicense Id for a given date.
    * @param businessLicenseId The Id of the business license to create attendance records for
    * @param effectiveDate The date to create the attendance records for
    * @param allOrNothingDML Should the DML operation to create the attendance__c records be all or nothing?
    * @return list of created Attendance__c records 
    */
    public static list<Attendance__c> generateAttendanceRecords(Id businessLicenseId, Date effectiveDate, boolean allOrNothingDML){
        return generateAttendanceRecords(businessLicenseId, effectiveDate, allOrNothingDML, null);
    }
    public static list<Attendance__c> generateAttendanceRecords(Id businessLicenseId, Date effectiveDate, boolean allOrNothingDML, id householdId){
        list<Attendance__c> allAttendanceRecords = new list<Attendance__c>();
        AttendanceTriggerHelper helper = new AttendanceTriggerHelper();

        try{
            list<EnrollmentWrapper> enrollees = getAllEnrolleesForLicense(businessLicenseId, effectiveDate, effectiveDate, householdId);
            list<Attendance__c> newAttendanceRecords = new list<Attendance__c>();
            for(EnrollmentWrapper thisEnrollment : enrollees){

                //if this enrollment does not have an attendance record for this day
                if(thisEnrollment.record.Attendances__r.isEmpty()){
                    Attendance__c thisAttendance = new Attendance__c();
                    thisAttendance.Name = thisEnrollment.record.Child__r.Firstname + ' ' +  thisEnrollment.record.Child__r.Lastname + ' ' + effectiveDate.format();
                    thisAttendance.Enrollment__r = thisEnrollment.record;
                    thisAttendance.Enrollment__c = thisEnrollment.record.Id;
                    thisAttendance.Schedule_Date__c = effectiveDate;       
                    thisAttendance.Unique_Identifier__c = AttendanceTriggerHelper.createUniqueIdString(effectiveDate, thisAttendance.Enrollment__r?.Child__r?.Unique_Identifier__c); 
                    newAttendanceRecords.add(thisAttendance);   
                }else{
                    //if they have an existing attendance record then add it to our complete list to return
                    allAttendanceRecords.add(thisEnrollment.record.Attendances__r[0]);
                }
                
            }

            system.debug('\n\n\n--- Upserting attendance records');      
            //insert the attendanc records that don't exist
            list<Database.UpsertResult> upsertResults = Database.upsert(newAttendanceRecords, Attendance__c.Unique_Identifier__c, allOrNothingDML);

            integer index =0;
            integer numSuccess = 0;
            for(Database.UpsertResult thisResult : upsertResults){
                if(!thisResult.isSuccess()){
                    for(Database.Error thisError : thisResult.getErrors()) {   
                        handleError(new DataException('\n\n---- Error creating attendance record ' + thisError.getStatusCode() + ': ' + thisError.getMessage() + ' ' + JSON.serializePretty(newAttendanceRecords[index])));
                    }
                }else{
                    numSuccess++;
                }
                index++;
            }

            if(numSuccess != upsertResults.size()) throw new DataException('\n\n\n-------- ALERT! There were errors inserting Attendance records for students. Please review the logs to find the source of the error\n\n\n');
            allAttendanceRecords.addAll(newAttendanceRecords);
            
        }catch (Exception ex) {
            system.debug('\n\n\n----- Error Generating Attendance Records!');
            system.debug(ex.getMessage() + ' on line ' + ex.getLineNumber() + '. ' + ex.getCause() + '. ' + ex.getStackTraceString());
            Logger.Instance.logErrorWithRT(ex, 'Getting the Error while calling generateAttendanceRecords', 'AttendanceUtilities','generateAttendanceRecords',Logger.LOG_TYPES.Attendance);
        	return null;
        }finally{
            Logger.Instance.push();
        }
        return allAttendanceRecords;
    }

    /**
    * @description Gets all the attendance_tracking__c records for a given attendance__c record id in a container object that also contains information about the
    * attendance__c record and the related contact__ record
    * @param attendanceRecordId Id of parent attendance__c record to fetch attendance_tracking__c records for
    * @return AttendanceTrackingWrapperContainer a container wrapper object containing information about the attendance__c record, contact and tracking__c records. 
    * properties come back defined but empty if no matching attendance__c is found.
    */
    public static AttendanceTrackingWrapperContainer getAttendanceTrackingData(id attendanceRecordId){
        AttendanceTrackingWrapperContainer thisContainer = new AttendanceTrackingWrapperContainer();
        try {
            //get info for the attendance record. Prefer to do it in a separate query in case there are no tracking records yet we still have attendance and contact data
            list<Attendance__c> attendanceRecord = [SELECT  Id,
                                                            Enrollment__r.Child__r.Firstname,
                                                            Enrollment__r.Child__r.Lastname,
                                                            First_Check_In__c,
                                                            Schedule_Date__c,
                                                            Has_Open_Check_In__c
                                                    FROM Attendance__c
                                                    WHERE Id = :attendanceRecordId
                                                    LIMIT 1];

            //if query is empty, just return null.
            if(attendanceRecord.isEmpty()) return thisContainer;

            thisContainer.attendanceRecord = attendanceRecord[0];
            thisContainer.contact = attendanceRecord[0].Enrollment__r.Child__r;

            list<Attendance_Tracking__c> trackingRecords = [SELECT 
                                                                Name,
                                                                Check_In__c,
                                                                Check_Out__c,
                                                                Checked_In__c,
                                                                Checked_In_By__c,
                                                                Checked_Out__c,
                                                                Checked_In_By__r.Name,
                                                                Checked_Out_By__r.Name,
                                                                Checked_Out_By__c,
                                                                Stay_Length_Minutes__c,
                                                                CCMS_SourceName__c,
                                                                CCMS_SourceId__c
                                                            FROM Attendance_Tracking__c
                                                            WHERE Attendance__c = :attendanceRecordId
                                                            ORDER BY Check_In__c ASC];
            for(Attendance_Tracking__c thisRecord : trackingRecords){
                if(thisContainer.attendanceRecord == null) thisContainer.attendanceRecord = thisRecord.Attendance__r;
                thisContainer.tracking.add(new AttendanceTrackingWrapper(thisRecord));
            } 
                  
        }catch (Exception ex) {
            system.debug('\n\n\n----- Error Getting Attendance Tracking Data!');
            system.debug(ex.getMessage() + ' on line ' + ex.getLineNumber() + '. ' + ex.getCause() + '. ' + ex.getStackTraceString());
            Logger.Instance.logErrorWithRT(ex, 'Getting the Error while calling AttendanceTrackingWrapperContainer', 'AttendanceUtilities','AttendanceTrackingWrapperContainer',Logger.LOG_TYPES.Attendance);
        	return null;
        }finally{
            Logger.Instance.push();
        }

        return thisContainer;
    }

    /**
    * @description Gets all users related to a given business license record through BusinessLicenseRole records. The  BusinessLicenseRole must be set to isActive__c = true
    * @param businessLicenseIds the ids of the business licenses to get all related users for
    * @return map of business license it to all users related to the business license via a BusinessLicenseRole junction record that is active.
    */
    // public static map<id,list<User>> getBusinessLicenseUsers(set<id> businessLicenseIds){
    //     try{    
    //         map<id,list<User>> licenseUsersMap = new map<id,list<User>>();
    
    //         list<BusinessLicense> businessLicenses = [SELECT 
    //                                                     Id, 
    //                                                     Name,
    //                                                     UserId,
    //                                                     (SELECT User__c
    //                                                      FROM Business_License_Roles__r
    //                                                      WHERE isActive__c = true AND
    //                                                      User__c != null) 
    //                                                  FROM BusinessLicense
    //                                                  WHERE Id in :businessLicenseIds];
    //         for(BusinessLicense thisLicense : businessLicenses){
    //             //if(thisLicense.UserId != null) licenseUsers.add(new User(Id=thisLicense.UserId));
    
    //             list<user> licenseUsers = licenseUsersMap.containsKey(thisLicense.Id) ? licenseUsersMap.get(thisLicense.Id) : new list<User>();
    
    //             for(Business_License_Role__c thisRole : thisLicense.Business_License_Roles__r){
    
        
    //                 /*
    //                 String accessLevel;
    //                 if(blr.Provider_Hub_Access_Level__c == 'Delegated Authority' || blr.Provider_Hub_Access_Level__c == 'Create/Submit'){
    //                     accessLevel = 'Edit';
    //                 }else if(blr.Provider_Hub_Access_Level__c == 'Read Only'){
    //                     accessLevel = 'Read';
    //                 }
    //                 if(accessLevel != ''){
    //                     List<RegulatoryTrxnFee> feesToAssign = licenseToFeeMap.get(blr.Business_License__c);
    //                     for(RegulatoryTrxnFee fee :feesToAssign){
    //                         RegulatoryTrxnFeeShare feeShare = new RegulatoryTrxnFeeShare();
    //                         feeShare.ParentId = fee.Id;
    //                         feeShare.AccessLevel = accessLevel;
    //                         feeShare.UserOrGroupId = blr.User__c;
    //                         feeShare.RowCause = 'Manual';
    //                         feeShares.add(feeShare);
                            
    //                     }
    //                 }
    //                 */
                    
    //                 if(thisRole.User__c != null) licenseUsers.add(new User(Id=thisRole.User__c));
    //             }
    
    //             licenseUsersMap.put(thisLicense.Id,licenseUsers);
    //         }
    //         return licenseUsersMap;
    //     }catch (Exception ex) {
    //         Logger.Instance.logErrorWithRT(ex, 'Getting the Error while calling getBusinessLicenseUsers', 'AttendanceUtilities','getBusinessLicenseUsers',Logger.LOG_TYPES.Attendance);
    //     	return null;
    //     }finally{
    //         Logger.Instance.push();
    //     }    
       
    // }

    //----------------------------------------------------- PRIVATE METHODS ------------------------------------------------- //

    /**
    * @description Creates Attendance__Share records to share Attendance__c records related to a BusinessLicense with the Users in the given Business_License_Role__c records.
    * this as an 'overloaded' version of the original method that supports the @future annotation to allow for higher processing limits and asyncronous processing as many many records
    * may be created at once.
    * @param blRoleIds A set of Business_License_Role__c record ids to evaluate and grant access to Attendance__c records for.
    * @return void
    */
    @future
    public static void shareAttendanceForBusinessLicenseRoles(set<Id> blRoleIds){

        map<Id,Business_License_Role__c> blRoles = new map<Id,Business_License_Role__c>([SELECT Business_License__c, 
                                                                                                User__c, 
                                                                                                Provider_Hub_Access_Level__c 
                                                                                        FROM  Business_License_Role__c 
                                                                                        WHERE Id in: blRoleIds]);

        shareAttendanceForBusinessLicenseRoles(blRoles);
    }

    /**
    * @description Creates Attendance__Share records to share Attendance__c records related to a BusinessLicense with the Users in the given Business_License_Role__c records.
    * @param blRoles A map of Business_License_Role__c record ids to evaluate and grant access to Attendance__c records for. The records in the map must have the User__c, Attendance__c, and Provider_Hub_Access_Level__c field populated.
    * @return A list of sharing request results that contain the results of the sharing operation. 
    */
    public static list<AttendanceUtilities.ShareRequestResult> shareAttendanceForBusinessLicenseRoles(map<Id,Business_License_Role__c> blRoles){
        try{
            list<AttendanceUtilities.ShareRequestResult> shareResults = new list<AttendanceUtilities.ShareRequestResult>();
    
    
            //for every incoming business license role we need to find every attendance record that belongs to the same BusinessLicense via an enrollment record
            //and create shares for them
    
            Map<Id,set<Id>> businessLicenseMap = new Map<Id,set<Id>>();
    
            Map<Id,sObject> relatedObjectInfo = new Map<Id,sObject>();
    
            List<Attendance__Share> shares = new List<Attendance__Share>();
    
            //get info about the current running user so it can be logged when we create our share records
            User thisUser = [SELECT Username, firstname, lastname, email FROM USER WHERE Id = :UserInfo.getUserId()];
    
            for(Business_License_Role__c thisRole : blRoles.values()){
                String accessLevel = getAccessLevelFromBusinessLicenseRole(thisRole);
                if(accessLevel == null){
                    system.debug('\n\n\n----- No access granted for Role: ' + thisRole.Id);
                    continue;
                }
                businessLicenseMap.put(thisRole.Business_License__c,new set<Id>());
            }
    
            //get all of the attendance records for any of our business licenses that were referenced. Use the efficient chunking of the SOQL For loop since there
            //might be a ton of records here.
            for(Attendance__c thisAttendance : [SELECT Id, 
                                                       Enrollment__r.Business_License__c,
                                                       Has_Open_Check_In__c 
                                                FROM Attendance__c 
                                                WHERE Enrollment__r.Business_License__c in :businessLicenseMap.keySet() 
                                                AND Enrollment__r.Business_License__c != null]){
                set<id> attendanceIdSet = businessLicenseMap.get(thisAttendance.Enrollment__r.Business_License__c);
                attendanceIdSet.add(thisAttendance.Id);
                businessLicenseMap.put(thisAttendance.Enrollment__r.Business_License__c,attendanceIdSet);
            }
    
            for(Business_License_Role__c thisRole : blRoles.values()){
    
                String accessLevel = getAccessLevelFromBusinessLicenseRole(thisRole);
                if(accessLevel == null) continue;
    
                //get all the attendance records for this business license
                set<Id> businessLicenseAttendanceRecords = businessLicenseMap.get(thisRole.Business_License__c);
    
                for(Id thisAttendanceRecordId : businessLicenseAttendanceRecords){
                    
                    Attendance__Share thisShare = new Attendance__Share(
                        ParentId = thisAttendanceRecordId,
                        AccessLevel = accessLevel,
                        UserOrGroupId = thisRole.User__c,
                        RowCause = 'Manual'
                    );
    
                    shares.add(thisShare);
                }    
            }    
    
            //insert our shares 
            list<Database.SaveResult> sr = Database.insert(shares,false);
    
            //evaluate the results of the sharing
            integer i = 0;
            for(Database.SaveResult thisSaveResult : sr){
    
                //if we resolved related record data, attempt to fetch it now for the creatio of our sharingRequestResult object. Otherwise just pass in null
                object target = relatedObjectInfo.containsKey((Id) shares[i].get('UserOrGroupId')) ? relatedObjectInfo.get((Id) shares[i].get('UserOrGroupId')) : null;
                object record = relatedObjectInfo.containsKey((Id) shares[i].get('ParentId')) ? relatedObjectInfo.get((Id) shares[i].get('ParentId')) : null;
                AttendanceUtilities.ShareRequestResult thisResult = new AttendanceUtilities.ShareRequestResult(thisSaveResult,shares[i],target,record,thisUser);
                shareResults.add(thisResult);
                i++;
            }
            return shareResults;
        }catch (Exception ex) {
            Logger.Instance.logErrorWithRT(ex, 'Getting the Error while calling shareAttendanceForBusinessLicenseRoles', 'AttendanceUtilities','shareAttendanceForBusinessLicenseRoles',Logger.LOG_TYPES.Attendance);
        	return null;
        }finally{
            Logger.Instance.push();
        }
    }

    public static string getAccessLevelFromBusinessLicenseRole(Business_License_Role__c thisRole){
        if(thisRole.Provider_Hub_Access_Level__c == 'Delegated Authority' || thisRole.Provider_Hub_Access_Level__c == 'Create/Submit' 
          || thisRole.Provider_Hub_Access_Level__c == 'Attendance Entry' || thisRole.Provider_Hub_Access_Level__c == 'Clerical'){
            return 'Edit';
        }else if(thisRole.Provider_Hub_Access_Level__c == 'Read Only'){
            return 'Read';
        }
        return null;
    }

    /**
    * @description Creates Apex sharing records for the given shareTargets with the given accessLevel to all the records in the list of record Ids provided. Can create
    * multiple types of shares for different objects in one invocation.
    * @param shareTargets the user(s) or group(s) id with whom to share the records
    * @param recordIds the records to grant access to
    * @param defaultAccessLevel the level of access (Edit/Read) to give to the shareTargets to all of the records if no entry is found in the UserIdRecordIdToPermissionMap with matching user/record in the key
    * @param resolveRecordNames Should additional queries be run to get related details (Name) for the related shareTargets and recordIds. Can help with debugging/logging
    * @param UserIdRecordIdToPermissionMap mapping of recordId+'-'+UserId->Access level to grant. If matching entry is not found defaultAccessLevel is used
    * @return a list of the results of creation of the share records. Contains information about the success of the share creation, error messages, and related record info.
    */
    // public static list<ShareRequestResult> createShares(set<Id> shareTargets, set<id> recordIds, string defaultAccessLevel, boolean resolveRecordNames){
    //     return createShares(shareTargets, recordIds, defaultAccessLevel, resolveRecordNames, new map<string,string>());
    // }
    // public static list<ShareRequestResult> createShares(set<Id> shareTargets, set<id> recordIds, string defaultAccessLevel, boolean resolveRecordNames, map<string,string> UserIdRecordIdToPermissionMap){
    //     try{
    //         //check to make sure we have a valid accessLevel provided
    //         if(defaultAccessLevel != 'Read' && defaultAccessLevel != 'Edit') throw new ApplicationException('Default access Level Must Be "Read" or "Edit".');
    
    //         //container to hold our sharing request results.
    //         list<ShareRequestResult> shareResults = new list<ShareRequestResult>();
    
    //         //map that is keyed by Share object type ("ContactShare", "CustomObject__Share", etc) to the list of records of that type to create
    //         map<string, list<sObject>> objectTypeToSharesMap = new map<string, list<sObject>>();
    
    //         //map of describe info for each parent object type (Contact, CustomObject__c, etc) so we know if it's custom or not so we can figure out the name of its
    //         //related Share object type (ContactShare, CustomObject__Share, etc)
    //         map<string,DescribeSObjectResult> describeResultMap = new map<string,DescribeSObjectResult>();
    
    //         //get info about the current running user so it can be logged when we create our share records
    //         User thisUser = [SELECT Username, firstname, lastname, email FROM USER WHERE Id = :UserInfo.getUserId()];
    
    //         for(Id thisId : recordIds){
    
    //             //deduce object type based on Id
    //             String sObjectType = String.valueOf(thisId.getSObjectType());
    
    //             system.debug('\n\n\n------------------ sObjectType Type: ' + sObjectType);
    
    //             //get describe info if we have it stored in the describeResultsMap, otherwise get the describe info now
    //             DescribeSObjectResult thisObjectDescribe = describeResultMap.containsKey(sObjectType) ? describeResultMap.get(sObjectType) : thisId.getSObjectType().getDescribe();
                
    //             //if our map doesn't have describe info for this type then write it back into the map for the next object of this type to get
    //             if(!describeResultMap.containsKey(sObjectType))  describeResultMap.put(sObjectType,thisObjectDescribe);
    
    //             //deduce/create the type of Share record we need. Standard objects just append the word Share after the object name. Custom objects use __Share
    //             Type shareType = thisObjectDescribe.isCustom() ? Type.forName(sObjectType.replace('__c','')+'__Share') :  Type.forName(sObjectType+'Share');
    
    //             system.debug('\n\n\n------------------ Share Type: ' + shareType);
    
    //             //get or create list of sharing records 
    //             list<sObject> objectShares = objectTypeToSharesMap.containsKey(sObjectType) ? objectTypeToSharesMap.get(sObjectType) : new list<sObject>();
    
    //             //for everyone/group who is getting access to this record, create a share record now.
    //             for(Id thisTarget : shareTargets){
    //                 sObject thisShare = (sObject) shareType.newInstance();
    //                 // Set the ID of record being shared.
    //                 thisShare.put('ParentId', thisId);
                        
    //                 // Set the ID of user or group being granted access.
    //                 thisShare.put('UserOrGroupId', thisTarget);
                        
    //                 // Set the access level.
    //                 thisShare.put('AccessLevel', UserIdRecordIdToPermissionMap.containsKey(thisId+'-'+thisTarget) ? UserIdRecordIdToPermissionMap.get(thisId+'-'+thisTarget) : defaultAccessLevel);
                        
    //                 // Set rowCause to 'manual' for manual sharing.
    //                 // This line can be omitted as 'manual' is the default value for sharing objects.
    //                 //jobShr.RowCause = Schema.Job__Share.RowCause.Manual;
    
    //                 objectShares.add(thisShare);
    //             }
    
    //             //write our sharing record back into our map that is keyed by type
    //             objectTypeToSharesMap.put(sObjectType, objectShares);
    //         }
    
    //         map<Id,sObject> queriedObjectResults = new map<Id,sObject>();
    
    //         //if we care about resolving the related object names...
    //         system.debug('\n\n\n--- resolveRecordNames? ' + resolveRecordNames);
    
    //         //now we do the additional querying work if we want to resolve related record names/additional info.
    //         if(resolveRecordNames){
    
    //             system.debug('\n\n\n--- Resolving Record Names');
    //             map<string, set<id>> shareTargetTypeToMembersMap = new map<string, set<id>>();
    
    //             //populate map with all sharing targets grouped by their type (User, Group)
    //             for(Id thisTargetId : shareTargets){
    
    //                 //figure out what kind of object this is by looking at the Id
    //                 string thisShareType = String.valueOf(thisTargetId.getSobjectType());
    
    //                 //get or create the set of Ids for this object type
    //                 set<id> thisTypeTargets = shareTargetTypeToMembersMap.containsKey(thisShareType) ? shareTargetTypeToMembersMap.get(thisShareType) : new set<Id>();
    
    //                 //add this id
    //                 thisTypeTargets.add(thisTargetId);
    
    //                 //save the set of ids back into the map keyed by object type
    //                 shareTargetTypeToMembersMap.put(thisShareType,thisTypeTargets);
    
    //             }
    
    //             system.debug('\n\n\n---- Built set of all share target ids');
    //             system.debug(shareTargetTypeToMembersMap);
    
    //             //now that our map contains all the entities of each type (User or Group) we can perform one query per object type to get all the related info
    //             for(string targetType : shareTargetTypeToMembersMap.keySet()){
                    
    //                 //get our list of record ids for this type
    //                 set<Id> targetIds = shareTargetTypeToMembersMap.get(targetType);
    
    //                 //do the query, create a map from the results keyed by the record id
    //                 Map<Id,sObject> targets = (Map<Id,sObject>) new map<Id,sObject>(Database.query('SELECT Name, ID FROM ' + targetType + ' WHERE ID IN :targetIds'));
    
    //                 //save our results back into our map of all record ids to record data
    //                 queriedObjectResults.putAll(targets);
    //             }
    
    //             system.debug('\n\n\n---- Got all share targets');
    //             system.debug(queriedObjectResults);
    
    //             //iterate over each object type in our list of types to records
    //             for(string objectTypeName : objectTypeToSharesMap.keySet()){
    
    //                 system.debug('\n\n\n---- objectTypeToShareMap Values For: ' + objectTypeName);
    //                 system.debug(objectTypeToSharesMap.get(objectTypeName));
    
    //                 //create a set of ids from the maps of object types to sharing records so we can get the ParentIds (record ids to query for)
    //                 set<id> thisObjectTypeRecordIds = new set<id>();
    //                 for(sObject thisShare : objectTypeToSharesMap.get(objectTypeName)){
    //                     thisObjectTypeRecordIds.add((Id) thisShare.get('ParentId'));
    //                 }
    
    //                 //perform query, create a map from the results keyed by record id with the record as the value
    //                 Map<Id,sObject> records = (Map<Id,sObject>) new map<Id,sObject>(Database.query('SELECT Name, ID FROM ' + objectTypeName + ' WHERE ID IN :thisObjectTypeRecordIds'));
                    
    //                 //save the results back to our master map of ids to records.
    //                 queriedObjectResults.putAll(records);
    //             }
    
    //             system.debug('\n\n\n------ All Resolved Records');
    //             system.debug(queriedObjectResults);
                
    //         }
    
    //         system.debug('\n\n\n------------ Inserting Shares');
    //         system.debug(JSON.serializePretty(objectTypeToSharesMap));
    
    //         //I don't know if you can insert more than 1 kind of share type per DML operation, so for now it's batched into each different share type
    //         //in almost all cases this loop should only execute once, maybe twice (it would be very strange to be creating a ton of different share types at once)
    //         for(string thisType : objectTypeToSharesMap.keySet()){
    //             list<sObject> newShares = objectTypeToSharesMap.get(thisType);
    
    //             system.debug('\n\n\n------------ Inserting Shares For: ' + thisType + ' - ' + newShares.size() + ' records');
    
    //             //insert our shares of this type
    //             list<Database.SaveResult> sr = Database.insert(newShares,false);
    
    //             //evaluate the results of the sharing
    //             integer i = 0;
    //             for(Database.SaveResult thisSaveResult : sr){
    
    //                 //if we resolved related record data, attempt to fetch it now for the creatio of our sharingRequestResult object. Otherwise just pass in null
    //                 object target = queriedObjectResults.containsKey((Id) newShares[i].get('UserOrGroupId')) ? queriedObjectResults.get((Id) newShares[i].get('UserOrGroupId')) : null;
    //                 object record = queriedObjectResults.containsKey((Id) newShares[i].get('ParentId')) ? queriedObjectResults.get((Id) newShares[i].get('ParentId')) : null;
    //                 ShareRequestResult thisResult = new ShareRequestResult(thisSaveResult,newShares[i],target,record,thisUser);
    //                 shareResults.add(thisResult);
    //                 i++;
    //             }
    //         }
    
    //         system.debug('\n\n\n------------ Share Results');
    //         system.debug(JSON.serializePretty(shareResults));
    //         return shareResults;
    //     }catch (Exception ex) {
    //         Logger.Instance.logErrorWithRT(ex, 'Getting the Error while calling createShares', 'AttendanceUtilities','createShares',Logger.LOG_TYPES.Attendance);
    //     	return null;
    //     }finally{
    //         Logger.Instance.push();
    //     }
    // }

    /**
    * @description Either updates existing Attendance_Tracking__c record with check in/out time. 
    * @param attendanceData list of of AttendeeWrapper objects containing check in information. Must contain populated attendanceRecord.Id values and checkedIn values at minimum.
    * @param allOrNothingDML controls if the DML is allOrNothing, useful for trying to backfill data when there may be errors during validations rules,etc
    * @return list of created/updated Attendance_Tracking__c records
    */
    private static list<AttendanceTrackingResultWrapper> setAttendanceTrackingStatus(list<AttendanceUtilities.AttendeeWrapper> attendanceData, boolean allOrNothingDML){

        List<AttendanceTrackingResultWrapper> resultWrapperList = new List<AttendanceTrackingResultWrapper>();

        map<string, Attendance_Tracking__c> recordsToUpsert = new map<string, Attendance_Tracking__c>();
        Id runningUserContact = null;

        list<User> portalUserContact = [SELECT Id, ContactId, IsActive 
                                        FROM User 
                                        WHERE Id =: userInfo.getUserId() 
                                        AND IsActive =: true
                                        LIMIT 1];

        if(!portalUserContact.isEmpty()){
            runningUserContact = portalUserContact[0].ContactId;
        }

        try{
            //find all attendance records and their most recent related attendance tracking record. We will then evaluate each one to see if
            //we need to create a new Attendance_Tracking__c record or update the existing.

            map<Id,AttendanceUtilities.AttendeeWrapper> attendanceDataByIdMap = new map<Id,AttendanceUtilities.AttendeeWrapper>();

            for(AttendeeWrapper thisWrapper : attendanceData){
                attendanceDataByIdMap.put(thisWrapper.attendanceRecord.Id,thisWrapper);
            }

            list<Attendance__c> attendanceQueryData = [SELECT Id,
                                                        Schedule_Date__c,
                                                        Enrollment__r.Child__r.Firstname,
                                                        Enrollment__r.Child__r.Lastname,
                                                        Enrollment__r.Child__r.Birthdate,
                                                        Enrollment__r.Child__r.Unique_Identifier__c,
                                                        Has_Open_Check_In__c,
                                                        (SELECT Check_In__c,
                                                                Check_Out__c,
                                                                Checked_In__c,
                                                                Checked_Out__c,
                                                                Attendance__c,
                                                                Checked_In_By_Contact__c,
                                                                Checked_Out_By_Contact__c,
                                                                Check_Out_User_Type__c,
                                                                Check_In_User_Type__c,
                                                                CCMS_SourceName__c,
                                                                CCMS_SourceId__c                                                                                                              
                                                        FROM Attendance_Tracking__r
                                                        //WHERE Checked_Out__c = false
                                                        ORDER BY Check_In__c, Check_Out__c DESC)
                                                FROM Attendance__c 
                                                WHERE Id in :attendanceDataByIdMap.keySet()];

            system.debug('\n\n\n---- attendanceQueryData');
            system.debug(JSON.serializePretty(attendanceQueryData));

            set<id> attendanceRecordIds = new set<id>();
            for(Attendance__c thisAttendanceRecord : attendanceQueryData){

                //most recent attendance_tracking__c record as ordered by the Check_In__c field
                Attendance_Tracking__c activeTrackingRecord = new Attendance_Tracking__c(Attendance__c=thisAttendanceRecord.Id);

                try{
                    AttendeeWrapper attendanceWrapper = attendanceDataByIdMap.get(thisAttendanceRecord.Id);

                    system.debug('\n\n\n---- Related Attendance Wrapper');
                    system.debug(JSON.serializePretty(attendanceWrapper));

                    
                    boolean checkIn = attendanceWrapper.checkedIn;

                    //in the case of creating a check in event 'after the fact' the user may be setting both the check-in time and check-out time in the
                    //same operation. This was not originally accounted for so the best way currently to handle this is to pass in a AttendeeWrapper with
                    //both the checkedIn and checkedOut flag set to true. While technically it's not a logically valid state it does allow us to create the record
                    //properly. So while it's weird and not ideal it works in this case.
                    boolean isCombined = attendanceWrapper.checkedIn && attendanceWrapper.checkedOut;
                    boolean noActiveAttendanceTracking = true;  

                    /*
                    we now need to find if there is 'active' tracking record. That means there is a check in time with no check out time. There are a few possibilities here
                    1) If this is a checkIn operation, but there is an active check in record, then we toss an error (handled below after the record info is populated)
                    2) If this is a checkIn operation, and there is no active tracking record then no problem, we create a new tracking record and populate it with the incoming data
                    3) If this is a checkOut operation and there is an active tracking record, then we update the active tracking record with the provided check out time.
                    4) If this is a checkOut operation but there is no active tracking record, then we toss an error (handled below after the record info is populated)
                    5) If this is a combined (both checkIn and checkOut) then it is irrelevant if there is an active tracking record as we are simply just creating a whole new attendance_tracking__c record 
                    */
                    for(Attendance_Tracking__c thisRelatedTrackingRecord : thisAttendanceRecord.Attendance_Tracking__r){
                        system.debug('\n\n\n---- Evaluating attendance tracking record with checkIn: ' +thisRelatedTrackingRecord.Check_In__c+ ' and checkOut: ' +thisRelatedTrackingRecord.Check_Out__c);
                        if(thisRelatedTrackingRecord.Check_In__c != null && thisRelatedTrackingRecord.Check_Out__c == null){
                            system.debug('\n\n\n--- Found active attendance tracking record');
                            system.debug(thisRelatedTrackingRecord);
                            noActiveAttendanceTracking = false;
                            activeTrackingRecord = thisRelatedTrackingRecord;
                        }
                    }
                    attendanceRecordIds.add(thisAttendanceRecord.Id);


                    system.debug('Number of related attendance tracking records:  ' + thisAttendanceRecord.Attendance_Tracking__r.size());
                    system.debug('Has Open Check In?: ' + thisAttendanceRecord.Has_Open_Check_In__c);
                    system.debug('Has Open existing attendance tracking? ' + !noActiveAttendanceTracking);
                    system.debug('check in (true) or check out (false): ' + checkIn);


                    /**
                     * Possible combinations
                     * 1) CheckIn, No existing record tracking record = create new (no record to modify. Need new)
                     * 2) CheckIn, Existing record has non null 'check out' date time = create new (previous record completed. Need new record)
                     * 3) CheckIn, Existing record has null 'check in' time = modify existing (record exists, can set check in time)
                     * 3.5) CheckIn, Existing record has non null 'check in' time = Throw error (Check in time was already set without setting check out time)
                     * 4) CheckOut, No existing record = Should not be possible = Throw error (cannot check out before check in)
                     * 5) CheckOut, Existing record has non null check out time = Throw error (checkout already set)
                     * 6) Checkout, Existing record has null check out time. = update
                     */
                    //if we are performing a check in action
                    if(checkIn){

                        //if there is no attendance tracking record for this attendance, OR the check out datetime is not empty, then we need to create a new attendance tracking record
                        

                        //outcomes 1 and 2
                        if(noActiveAttendanceTracking || thisAttendanceRecord.Attendance_Tracking__r[0].Check_Out__c != null){
                            system.debug('-------------------------------------------------- Outcome 1/2.  No existing record tracking record = create new (no record to modify. Need new). Linking to attendance: ' + thisAttendanceRecord.Id );
                        }
                        //outcome 3
                        else if(!noActiveAttendanceTracking && thisAttendanceRecord.Attendance_Tracking__r[0].Check_In__c == null){
                            system.debug('-------------------------------------------------- Outcome 3. CheckIn, Existing record has null checkin time = modify existing (record exists, can set check in time)');
                            activeTrackingRecord = thisAttendanceRecord.Attendance_Tracking__r[0];
                        }
                        else if(!noActiveAttendanceTracking && thisAttendanceRecord.Attendance_Tracking__r[0].Check_In__c != null){
                            system.debug('-------------------------------------------------- Outcome 3.5.  CheckIn, Existing record has non null checkin time = Throw error (Check in time was already set without setting check out time)');
                            throw new LogicException('Check in time for attendance ' + thisAttendanceRecord.Id + ' already set to ' + thisAttendanceRecord.Attendance_Tracking__r[0].Check_In__c + '. Skipping update');
                        }
                        //uncovered outcome
                        else{
                            system.debug('\n\n\n----- Un-covered logic branch for checkIn IF statments in performTrackingActions');
                            system.debug(JSON.serializePretty(thisAttendanceRecord));
                        }

                        activeTrackingRecord.Checked_In_By__c = UserInfo.getUserId();
                        activeTrackingRecord.Checked_In_By_Contact__c = attendanceWrapper.operatingContact != null ? attendanceWrapper.operatingContact : runningUserContact;
                        activeTrackingRecord.Check_In_User_Type__c = attendanceWrapper.operatingContact != null && attendanceWrapper.updatedCheckInTime != null ? 'Parent or Guardian' : 'Provider';
                        activeTrackingRecord.Checked_In__c = true;
                        activeTrackingRecord.Check_In__c = attendanceWrapper.updatedCheckInTime;

                    }else{
                        system.debug('CheckOut Action branch');
                        //outcome 4
                        if(noActiveAttendanceTracking){
                            system.debug('-------------------------------------------------- Outcome 4. CheckOut, No existing record = Should not be possible = Throw error (cannot check out before check in)');
                            throw new LogicException('No attendance tracking record found for attendance ' + thisAttendanceRecord.Id + '. Cannot perform checkout. Must check in first.');
                        }
                        //outcome 5
                        else if(!noActiveAttendanceTracking && activeTrackingRecord.Check_Out__c != null){
                            system.debug('-------------------------------------------------- Outcome 5. CheckOut, Existing record has non null check out time = Throw error (checkout already set)');
                            throw new LogicException('Check out time has already been set for attendance ' + thisAttendanceRecord.Id + '. Check in before attempting to set check out.');
                        }
                        else if(!noActiveAttendanceTracking && activeTrackingRecord.Check_Out__c == null){
                            system.debug('-------------------------------------------------- Outcome 6. Checkout, Existing record has null check out time. = update');
                        }
                    }

                    //in the case of a 'bulk' operation, the user may be setting both check in and check out times. So account for that now.
                    if(!checkIn || isCombined){
                        activeTrackingRecord.Checked_Out_By__c = UserInfo.getUserId();
                        activeTrackingRecord.Checked_Out_By_Contact__c = attendanceWrapper.operatingContact != null ? attendanceWrapper.operatingContact : runningUserContact;
                        activeTrackingRecord.Check_Out_User_Type__c = attendanceWrapper.operatingContact != null && attendanceWrapper.updatedCheckOutTime != null ? 'Parent or Guardian' : 'Provider';
                        activeTrackingRecord.Checked_Out__c = true;
                        activeTrackingRecord.Check_Out__c = attendanceWrapper.updatedCheckOutTime;
                    }
                    activeTrackingRecord.unique_identifier__c = AttendanceTrackingTriggerHelper.createUniqueIdString(activeTrackingRecord.Check_In__c, thisAttendanceRecord.Enrollment__r.Child__r.Unique_Identifier__c);
                   
                    if (checkIn && !isCombined && thisAttendanceRecord.Has_Open_Check_In__c) {
                        throw new LogicException('There is already an open check-in for this attendance. Please check out before creating a new check-in event.');
                    }

                    if (activeTrackingRecord.Check_In__c == null && activeTrackingRecord.Check_Out__c != null) {
                        throw new LogicException('A check-out time may not be logged without a check-in time.');
                    }

                    //because these records don't have ids yet we need to make something we can use to uniquely identify them so when we test for validity
                    //we know what results belong to what record.
                    recordsToUpsert.put(Crypto.getRandomInteger()+'-'+Crypto.getRandomInteger(), activeTrackingRecord);
                }
                catch(Exception e){
                    Logger.Instance.logErrorWithRT(e, 'Getting the Error while calling setAttendanceTrackingStatus', 'AttendanceUtilities','setAttendanceTrackingStatus',Logger.LOG_TYPES.Attendance);
                    
                    resultWrapperList.add(new AttendanceTrackingResultWrapper(activeTrackingRecord, false, e.getMessage()));
                }
            }

            //populate the attendance tracking records with their unique ids
            AttendanceTrackingTriggerHelper ATTH = new AttendanceTrackingTriggerHelper();
            updateMapValuesWithList(recordsToUpsert, ATTH.populateUniqueIdentifiers(recordsToUpsert.values(), false));

            list<Database.UpsertResult> saveResults = Database.upsert(recordsToUpsert.values(), Attendance_Tracking__c.Unique_Identifier__c, allOrNothingDML);

            integer i = 0;
            for(Database.UpsertResult upsertResult : saveResults){
                Attendance_Tracking__c trackingRecord = recordsToUpsert.values()[i];
                Boolean isSuccess = upsertResult.isSuccess();
                String errorMessage = '';

                if (!upsertResult.isSuccess()) {
                    for (Database.Error thisError : upsertResult.getErrors()) {
                        system.debug('\n\n\n-------------- Error Saving Record');
                        errorMessage += thisError.getStatusCode() + ': ' + thisError.getMessage() + ' ';
                        system.debug(recordsToUpsert.values()[i]);
                    }
                }

                resultWrapperList.add(new AttendanceTrackingResultWrapper(trackingRecord, isSuccess, errorMessage));

                i++;
            }
        }catch(Exception ex){
            system.debug('\n\n\n----- Error creating Attendance Tracking Records!');
            system.debug(ex.getMessage() + ' on line ' + ex.getLineNumber() + '. ' + ex.getCause() + '. ' + ex.getStackTraceString());
			Logger.Instance.logErrorWithRT(ex, 'Getting the Error while calling setAttendanceTrackingStatus', 'AttendanceUtilities','setAttendanceTrackingStatus',Logger.LOG_TYPES.Attendance);
        	return null;
        }finally{
            Logger.Instance.push();
        }

        return resultWrapperList;
    }

    /**
    * @description Creates Business_License_Role__c for the given BusinessLicense for the given userIds
    * @param businessLicenseId Id of businessLicense record to create roles for.
    * @param userIds set of ids to make roles for.
    * @return list of created businessLicenseRole
    */
    public static list<Business_License_Role__c> createBusinessLicenseRoles(id businessLicenseId, set<Id> userIds){
        list<Business_License_Role__c> blRoles = new list<Business_License_Role__c>();

        map<Id,User> userData =  (Map<Id,User>) new map<Id,User>([SELECT Firstname, Lastname, Email FROM User WHERE Id in :userIds]);
        for(Id thisUserId : userIds){
            User thisUser = userData.get(thisUserId);

            blRoles.add(new Business_License_Role__c(
                //Name = thisUser.Firstname + ' ' + thisUser.Lastname,
                Business_License__c	= businessLicenseId,
                User__c = thisUserId,
                isActive__c = true
            ));
        }

        insert blRoles;
        return blRoles;
    }
    /**
    * @description gets a list of attendeeWrapper objects for a given list of attendance__c record ids.
    * @param attendanceRecordIds list of ids of attendance__c record ids for which to generate AttendeeWrapper records
    * @return list of AttendeeWrapper objects that contain all information about attendance and related tracking records needed to build tables/etc 
    */
    private static list<AttendeeWrapper> getAttendeeWrappersFromRecords(list<Id> attendanceRecordIds){
        list<AttendeeWrapper> returnWrappers = new list<AttendeeWrapper>();
        try{
            list<Attendance__c> attendeeList = [SELECT Id,
                                                            Enrollment__c,
                                                            Is_Checked_In__c,
                                                            Is_Checked_Out__c,
                                                            First_Check_In__c,
                                                            Last_Checkout__c,
                                                            Enrollment__r.Child__r.Firstname,
                                                            Enrollment__r.Child__r.Lastname,
                                                            Enrollment__r.Child__r.Birthdate,
                                                            Number_Of_Open_Checkins__c,
                                                            Total_Minutes__c,
                                                            Number_of_Check_in_Events__c,
                                                            Schedule_Date__c,
                                                            Has_Open_Check_In__c,       
                                                            (SELECT Check_In__c,
                                                                    Check_Out__c,
                                                                    Checked_In__c,
                                                                    Checked_Out__c,
                                                                    Checked_In_By__r.firstname,
                                                                    Checked_In_By__r.lastname,
                                                                    Checked_Out_By__r.firstname,
                                                                    Checked_Out_By__r.lastname,
                                                                    CCMS_SourceName__c,
                                                                    CCMS_SourceId__c                                                         
                                                            FROM Attendance_Tracking__r
                                                            ORDER BY Check_In__c, Check_Out__c DESC
                                                            LIMIT 1)
                                                    FROM Attendance__c
                                                    WHERE Id in :attendanceRecordIds];
        
            for(Attendance__c thisAttendance : attendeeList){
                if(thisAttendance.Enrollment__r.Child__r != null) returnWrappers.add(new AttendeeWrapper(thisAttendance.Enrollment__r.Child__r, thisAttendance));
            }
        }catch(Exception ex){
            Logger.Instance.logErrorWithRT(ex, 'Getting the Error while calling getAttendeeWrappersFromRecords', 'AttendanceUtilities','getAttendeeWrappersFromRecords',Logger.LOG_TYPES.Attendance);
        	return null;
        }finally{
            Logger.Instance.push();
        }
        return returnWrappers;
    }


    /**
    * @description generic error handler. Logs the error to the console. May later be hooked up to org wide error handler to log via platform event
    * @param e exception to log
    * @return void 
    */
    public static void handleError(Exception e){
        system.debug('\n\n\n----- Error in AttendanceUtilities. ' + e.getMessage() + ' on line ' + e.getLineNumber() + '. ' + e.getCause());
        system.debug(e.getStackTraceString());
        system.debug(e);

        //maybe write to an error logging platform event object or something here?

        //if(Test.isRunningTest()) throw e;
    }

    /**
    * @description this method is to generate a PIN for a Parent when triggered from the experience site 
    * @param contactId contactToUpdate
    * @return void 
    */
    public static void generatePin(Id contactId){
        List<Contact> contactsToGeneratePin = [SELECT Id, Experience_PIN_Opt_In__c, Email, Parent_Adult_Experience_PIN__c, Preferred_Language__c From Contact Where Id = :contactId];

        try{
            AttendancePinGenerator.generateRandomPins(contactsToGeneratePin);
            AttendancePinGenerator.sendPinNewlyGeneratedEmail(contactsToGeneratePin);
        }
        catch(Exception ex){
            throw new omnistudio.ApplicationService.ApplicationException(ex.getMessage());
        }
    }

    public static Object findDuplicatesChildren(String childRecordsString, String businessLicenseId){
        List<Contact> contactsToCheckDupes = new List<Contact>();
        List<Id> foundDuplicatesId = new List<Id>();
        List<Id> foundDuplicatesIdWithinBusinessLicense = new List<Id>();
        Map<String, ChildInformationWrapper> duplicateUniqueIdToChildInformation = new Map<String, ChildInformationWrapper>();

        List<ChildInformationWrapper> childRecords = (List<ChildInformationWrapper>) JSON.deserialize(childRecordsString, List<ChildInformationWrapper>.class);
        //Query recordtype
        Id childRecordTypeId = ([Select Id, DeveloperName From RecordType WHERE DeveloperName = 'Child' LIMIT 1]).Id;

        for(ChildInformationWrapper obj : childRecords){
            if(obj.childId == null){
                Contact dupeContact = new Contact();
                dupeContact.FirstName = obj.childFirstName.capitalize();
                dupeContact.LastName = obj.childLastName.capitalize();
                dupeContact.BirthDateText__c = obj.childDateOfBirth;
                dupeContact.Program_Participation__c = 'Enrollment and Attendance';
                dupeContact.RecordTypeId = childRecordTypeId;

                contactsToCheckDupes.add(dupeContact);
                duplicateUniqueIdToChildInformation.put(dupeContact.FirstName+';'+dupeContact.LastName+';'+dupeContact.BirthDateText__c, obj);
            }
        }

        if(contactsToCheckDupes.size() <= 0){
            return null;
        }

        //query for the duplicates
        Datacloud.FindDuplicatesResult[] results = Datacloud.FindDuplicates.findDuplicates(contactsToCheckDupes);

        for (Datacloud.FindDuplicatesResult findDupeResult : results) {
            for (Datacloud.DuplicateResult dupeResult : findDupeResult.getDuplicateResults()) {
                for (Datacloud.MatchResult matchResult : dupeResult.getMatchResults()) {
                    for (Datacloud.MatchRecord matchRecord : matchResult.getMatchRecords()) {
                        foundDuplicatesId.add(matchRecord.getRecord().Id);
                    }
                }
            }
        }

        if (foundDuplicatesId.size() <= 0) {
            return null;
        }

        //query Business License , extract ACRS within Business license

        //get all enrollments related to dupes. This is where we remove duplicates not in the same BusinessLicense
        Map<String, Enrollment__c> contactToEnrollmentRecord = new Map<String, Enrollment__c>();
        List<Enrollment__c> enrollmentRecords = [SELECT Id, Child__c, Status__c, Start_Date__c, End_Date__c, Termination_Date__c From Enrollment__c 
                                                WHERE Business_License__c =:businessLicenseId 
                                                AND Child__c in :foundDuplicatesId
                                                ORDER BY CreatedDate DESC
                                                ];

        for (Enrollment__c enrollmentRecord : enrollmentRecords) {
            foundDuplicatesIdWithinBusinessLicense.add(enrollmentRecord.Child__c);
            if(!contactToEnrollmentRecord.containsKey(enrollmentRecord.Child__c)) contactToEnrollmentRecord.put(enrollmentRecord.Child__c, enrollmentRecord);
        }

        //return null when there are no duplicates found
        if(foundDuplicatesIdWithinBusinessLicense.size() <= 0){
            return null;
        }

        //query full Contact Information
        Map<Id, Contact> duplicateContactsFullInfo = new Map<Id, Contact>([Select FirstName, LastName, Name, BirthDateText__c FROM Contact WHERE Id in :foundDuplicatesIdWithinBusinessLicense]);

        //compile uicontacts unique Id to Contact Id
        Map<String, Map<Id, Contact>> duplicateContactUniqueIdToContactId = new Map<String, Map<Id, Contact>>();

        for (Contact duplicateContactsFullInfoRecord : duplicateContactsFullInfo.values()) {
            String uniqueKey = duplicateContactsFullInfoRecord.FirstName.capitalize()+';'+duplicateContactsFullInfoRecord.LastName.capitalize()+';'+duplicateContactsFullInfoRecord.BirthdateText__c;
            if(duplicateContactUniqueIdToContactId.containsKey(uniqueKey)){
                duplicateContactUniqueIdToContactId.get(uniqueKey).put(duplicateContactsFullInfoRecord.Id, duplicateContactsFullInfoRecord);
            }
            else {
                Map<Id, Contact> contactMap = new Map<Id, Contact>();
                contactMap.put(duplicateContactsFullInfoRecord.Id, duplicateContactsFullInfoRecord);
                duplicateContactUniqueIdToContactId.put(uniqueKey, contactMap);
            }
        }

        List<Id> relatedAcrToDuplicateChildAccountIds = new List<Id>();
        //TODO: filter acr based on household.
        //query all ACRs related to all duplicate contact Ids
        List<AccountContactRelation> relatedAcrToDuplicateChild = [SELECT Id, AccountId, Account.Name, ContactId, Contact.FirstName, Contact.LastName, Contact.BirthDateText__c From AccountContactRelation
        WHERE ContactId in :foundDuplicatesIdWithinBusinessLicense and Account.RecordType.DeveloperName = 'Household'];

        //Map of Duplicate contact to its list of corresponding ACR
        Map<String, Map<String, AccountContactRelation>> duplicateContactIdToACRs =  new Map<String, Map<String, AccountContactRelation>>();

        //map each contactIdFromDuplicates to its corresponding ACR

        //compile AccountIds of each ACR to query for constituents
        for (AccountContactRelation acrRecordForDup : relatedAcrToDuplicateChild) {
            relatedAcrToDuplicateChildAccountIds.add(acrRecordForDup.AccountId);
            if(duplicateContactIdToACRs.containsKey(acrRecordForDup.ContactId)){
                duplicateContactIdToACRs.get(acrRecordForDup.ContactId).put(acrRecordForDup.AccountId, acrRecordForDup);
            }
            else{
                Map<String, AccountContactRelation> newDuplicateContactIdToACRsMap = new Map<String, AccountContactRelation>();
                newDuplicateContactIdToACRsMap.put(acrRecordForDup.AccountId, acrRecordForDup);
                duplicateContactIdToACRs.put(acrRecordForDup.ContactId, newDuplicateContactIdToACRsMap);
            }
        }

        //query constituents related to duplicate Acrs
        List<AccountContactRelation> relatedAcrToDuplicateChildConstituents = [SELECT Id, AccountId, ContactId, Contact.FirstName, Contact.LastName, Contact.Name, Contact.BirthDateText__c, TOLABEL(Contact.RelationshipToChild__c), PrimaryAdultRelationshipToChild__c From AccountContactRelation
        WHERE AccountId in :relatedAcrToDuplicateChildAccountIds AND Account.RecordType.DeveloperName = 'Household' AND Contact.RecordType.DeveloperName = 'Constituent'];
        //map household Id to ACR
        Map<String, List<AccountContactRelation>> allHouseholdsToConstituents = new Map<String, List<AccountContactRelation>>();

        for (AccountContactRelation constituent : relatedAcrToDuplicateChildConstituents) {
            if (allHouseholdsToConstituents.containsKey(constituent.AccountId)) {
                allHouseholdsToConstituents.get(constituent.AccountId).add(constituent);
            }
            else{
                allHouseholdsToConstituents.put(constituent.AccountId, new List<AccountContactRelation>{constituent});
            }
        }

        Map<String, DuplicateContactWrapper> duplicateContactIdToWrapper = new Map<String, DuplicateContactWrapper>();

        //for each Main ACR
        for (Id duplicateContact : duplicateContactIdToACRs.keySet()) {
            DuplicateContactWrapper duplicateContactWrapperRecord = new DuplicateContactWrapper();
            duplicateContactWrapperRecord.Id = duplicateContact;
            duplicateContactWrapperRecord.contactRecord = duplicateContactsFullInfo.get(duplicateContact);
            
            Enrollment__c duplicateContactEnrollment = contactToEnrollmentRecord.get(duplicateContact);

            if(duplicateContactEnrollment != null && duplicateContactEnrollment.Status__c == 'Ended'){
                duplicateContactWrapperRecord.enrollmentExpired = true;
            }  
             
            if(duplicateContactEnrollment != null && duplicateContactEnrollment.Status__c == 'Paused'){
                duplicateContactWrapperRecord.enrollmentPaused = true;
            } 
            //get the Account ACRs
            Map<String, AccountContactRelation> contactAcrs = duplicateContactIdToACRs.get(duplicateContact);
            List<HouseholdInformationWrapper> householdPerDuplicateList = new List<HouseholdInformationWrapper>();

            for (String acrAccountId : contactAcrs.keySet()) {
                if(allHouseholdsToConstituents.containsKey(acrAccountId) && allHouseholdsToConstituents.get(acrAccountId) != null){
                    HouseholdInformationWrapper houseHoldWrapper = new HouseholdInformationWrapper();
                    houseHoldWrapper.householdName = contactAcrs.get(acrAccountId).Account.Name;
                    houseHoldWrapper.householdDetails = new List<Contact>();
                
                    for (AccountContactRelation acrVar : allHouseholdsToConstituents.get(acrAccountId)) {
                        houseHoldWrapper.householdDetails.add(acrVar.Contact);
                    }
                    householdPerDuplicateList.add(houseHoldWrapper);
                }
            }

            duplicateContactWrapperRecord.householdInformation = householdPerDuplicateList;

            duplicateContactIdToWrapper.put(duplicateContact, duplicateContactWrapperRecord);
        }

        //finally loop through entries from ui and add corresponding records
        //map unique key to list of Map<duplicateContactId,DuplicateContactWrapper>
        Map<String, DuplicateEntryWrapper> outputMap = new Map<String, DuplicateEntryWrapper>();
        List<Map<String, Map<String, DuplicateContactWrapper>>> output = new List<Map<String, Map<String, DuplicateContactWrapper>>>();
        for (String uniqueId : duplicateContactUniqueIdToContactId.keySet()) {
            if (duplicateUniqueIdToChildInformation.containsKey(uniqueId)) {
                DuplicateEntryWrapper dupEntryWrapper = new DuplicateEntryWrapper();
                dupEntryWrapper.name = duplicateUniqueIdToChildInformation.get(uniqueId).childFirstName + ' ' + duplicateUniqueIdToChildInformation.get(uniqueId).childLastName;
                dupEntryWrapper.uniqueId = uniqueId;
                Map<Id, Contact> contactMap = duplicateContactUniqueIdToContactId.get(uniqueId);
                
                Map<String, DuplicateContactWrapper> duplicateWrapperMap = new Map<String, DuplicateContactWrapper>();
                for (Id duplicateContactId : contactMap.keySet()) {
                    duplicateWrapperMap.put(duplicateContactId,duplicateContactIdToWrapper.get(duplicateContactId));
                }
                dupEntryWrapper.duplicateEntries = duplicateWrapperMap;
                outputMap.put(uniqueId, dupEntryWrapper);
            }
        }
        
        return outputMap;
    }

    public static Object findDuplicatesConstituents(String constituentsRecordsString, String businessLicenseId, String constituentType){
        List<Contact> contactsToCheckDupes = new List<Contact>();
        List<Id> foundDuplicatesId = new List<Id>();
        Set<Id> childIdsRelatedToDuplicates = new Set<Id>();
        Map<String, ConstituentInformationWrapper> duplicateUniqueIdToConstituentInformation = new Map<String, ConstituentInformationWrapper>();


        List<ConstituentInformationWrapper> constituentRecords = (List<ConstituentInformationWrapper>) JSON.deserialize(constituentsRecordsString, List<ConstituentInformationWrapper>.class);

        //Query recordtype
        Id constituentRecordTypeId = ([Select Id, DeveloperName From RecordType WHERE DeveloperName = 'Constituent' LIMIT 1]).Id;
        //get duplicates
        for(ConstituentInformationWrapper obj : constituentRecords){
            if(obj.guardianId == null && obj.trustedId == null){
                Contact dupeContact = new Contact();
                dupeContact.FirstName = constituentType == 'parent' ? obj.guardianFirstName.capitalize() : obj.trustedFirstName.capitalize();
                dupeContact.LastName = constituentType == 'parent' ? obj.guardianLastName.capitalize() : obj.trustedLastName.capitalize();
                dupeContact.Program_Participation__c = 'Enrollment and Attendance';
                dupeContact.Record_Type_Name2__c = 'Constituent';
                dupeContact.RecordTypeId = constituentRecordTypeId;
    
                contactsToCheckDupes.add(dupeContact);
                duplicateUniqueIdToConstituentInformation.put(dupeContact.FirstName+';'+dupeContact.LastName, obj);
            }
        }

        if(contactsToCheckDupes.size() <= 0){
            return null;
        }

        //query for the duplicates
        Datacloud.FindDuplicatesResult[] results = Datacloud.FindDuplicates.findDuplicates(contactsToCheckDupes);

        for (Datacloud.FindDuplicatesResult findDupeResult : results) {
            for (Datacloud.DuplicateResult dupeResult : findDupeResult.getDuplicateResults()) {
                for (Datacloud.MatchResult matchResult : dupeResult.getMatchResults()) {
                    for (Datacloud.MatchRecord matchRecord : matchResult.getMatchRecords()) {
                        foundDuplicatesId.add(matchRecord.getRecord().Id);
                    }
                }
            }
        }

        if (foundDuplicatesId.size() <= 0) {
            return null;
        }

        //query full Contact Information
        Map<Id, Contact> duplicateContactsFullInfo = new Map<Id, Contact>([Select FirstName, LastName, Name, BirthDateText__c FROM Contact WHERE Id in :foundDuplicatesId]);

        //compile uicontacts unique Id to Contact Id
        Map<String, Map<Id, Contact>> duplicateContactUniqueIdToContactId = new Map<String, Map<Id, Contact>>();

        for (Contact duplicateContactsFullInfoRecord : duplicateContactsFullInfo.values()) {
            String uniqueKey = duplicateContactsFullInfoRecord.FirstName.capitalize()+';'+duplicateContactsFullInfoRecord.LastName.capitalize();
            if(duplicateContactUniqueIdToContactId.containsKey(uniqueKey)){
                duplicateContactUniqueIdToContactId.get(uniqueKey).put(duplicateContactsFullInfoRecord.Id, duplicateContactsFullInfoRecord);
            }
            else {
                Map<Id, Contact> contactMap = new Map<Id, Contact>();
                contactMap.put(duplicateContactsFullInfoRecord.Id, duplicateContactsFullInfoRecord);
                duplicateContactUniqueIdToContactId.put(uniqueKey, contactMap);
            }
        }


        //We need the ACRs to determine the children related to the enrollment
        //query acrs related to contact Ids in duplicates
        List<Id> relatedAcrToDuplicateConstituentsAccountIds = new List<Id>();
        
        //TODO: filter acr based on household.
        //query all ACRs related to all duplicate contact Ids for households
        List<AccountContactRelation> relatedAcrToDuplicateConstituent = [SELECT Id, AccountId, Account.Name, ContactId, Contact.FirstName, Contact.LastName, Contact.BirthDateText__c From AccountContactRelation
        WHERE ContactId in :foundDuplicatesId and Account.RecordType.DeveloperName = 'Household'];

        //Map of Duplicate contact to its list of corresponding ACR
        Map<String, Map<String, AccountContactRelation>> duplicateContactIdToACRs =  new Map<String, Map<String, AccountContactRelation>>();

        //compile AccountIds of each ACR to query for constituents
        for (AccountContactRelation acrRecordForDup : relatedAcrToDuplicateConstituent) {
            relatedAcrToDuplicateConstituentsAccountIds.add(acrRecordForDup.AccountId);
            if(duplicateContactIdToACRs.containsKey(acrRecordForDup.ContactId)){
                duplicateContactIdToACRs.get(acrRecordForDup.ContactId).put(acrRecordForDup.AccountId, acrRecordForDup);
            }
            else{
                Map<String, AccountContactRelation> newDuplicateContactIdToACRsMap = new Map<String, AccountContactRelation>();
                newDuplicateContactIdToACRsMap.put(acrRecordForDup.AccountId, acrRecordForDup);
                duplicateContactIdToACRs.put(acrRecordForDup.ContactId, newDuplicateContactIdToACRsMap);
            }
        }

        //get a list of the child Ids to query within business license
        Set<Id> relatedAcrToDuplicateConstituentsChildIds = new Set<Id>();
        //Get Account ids related to the children
        Map<Id, Set<Id>> childIdsToHouseholds = new Map<Id, Set<Id>>();

        //query constituents related to duplicate Acrs
        List<AccountContactRelation> relatedAcrToDuplicateConstituents = [SELECT Id, AccountId, ContactId, Contact.FirstName, Contact.LastName, Contact.Name, Contact.BirthDateText__c, TOLABEL(Contact.RelationshipToChild__c),Contact.RecordType.DeveloperName, PrimaryAdultRelationshipToChild__c From AccountContactRelation
        WHERE AccountId in :relatedAcrToDuplicateConstituentsAccountIds AND Account.RecordType.DeveloperName = 'Household'];
        //map household Id to ACR
        Map<String, List<AccountContactRelation>> allHouseholdsToConstituents = new Map<String, List<AccountContactRelation>>();
        // Map<String, List<Id>> allChildIdToHouseholds = new Map<String, List<AccountContactRelation>>();

        for (AccountContactRelation constituent : relatedAcrToDuplicateConstituents) {
            if (constituent.Contact.RecordType.DeveloperName == 'Child') {
                relatedAcrToDuplicateConstituentsChildIds.add(constituent.ContactId);
                // houseHoldIdToChildIds.put(constituent.AccountId);
                if (childIdsToHouseholds.containsKey(constituent.ContactId)) {
                    childIdsToHouseholds.get(constituent.ContactId).add(constituent.AccountId);
                }
                else{
                    childIdsToHouseholds.put(constituent.ContactId, new Set<Id>{constituent.AccountId});
                }
            }
            if (allHouseholdsToConstituents.containsKey(constituent.AccountId)) {
                allHouseholdsToConstituents.get(constituent.AccountId).add(constituent);
            }
            else{
                allHouseholdsToConstituents.put(constituent.AccountId, new List<AccountContactRelation>{constituent});
            }
        }

        //get all enrollments related to dupes. This is where we remove duplicates not in the same BusinessLicense
        List<Enrollment__c> enrollmentRecords = [SELECT Id, Child__c From Enrollment__c WHERE Business_License__c =:businessLicenseId 
        AND Child__c in :relatedAcrToDuplicateConstituentsChildIds];

        for (Enrollment__c enrollmentRecord : enrollmentRecords) {
            //isolates only contactIds within this business license
            childIdsRelatedToDuplicates.add(enrollmentRecord.Child__c);//rename this var
        }

        //compile households within the enrollment childIds
        Set<Id> householdsRelatedToRelatedChildren = new Set<Id>();
        for (String childId : childIdsRelatedToDuplicates) {
            householdsRelatedToRelatedChildren.addAll(childIdsToHouseholds.get(childId));
        }

        //remove acrs not within the same business license by matching household Id
        for (Id duplicateContactId : duplicateContactIdToACRs.keySet()) {
            for (String householdId : duplicateContactIdToACRs.get(duplicateContactId).keySet()) {
                if(!householdsRelatedToRelatedChildren.contains(householdId)){
                    duplicateContactIdToACRs.get(duplicateContactId).remove(householdId);
                }
            }
            //remove contacts that has no household in them (after filtered from above we have to remove 
            //contacts with no households as it means they are not in the same business license)
            if(duplicateContactIdToACRs.get(duplicateContactId).isEmpty()){
                duplicateContactIdToACRs.remove(duplicateContactId);
            }
        }

        if (duplicateContactIdToACRs.isEmpty()) {
            return null;
        }

        Map<String, DuplicateContactWrapper> duplicateContactIdToWrapper = new Map<String, DuplicateContactWrapper>();


        //for each Main ACR
        for (Id duplicateContactId : duplicateContactIdToACRs.keySet()) {

            DuplicateContactWrapper duplicateContactWrapperRecord = new DuplicateContactWrapper();
            duplicateContactWrapperRecord.Id = duplicateContactId;
            duplicateContactWrapperRecord.contactRecord = duplicateContactsFullInfo.get(duplicateContactId);
            //get the Account ACRs
            Map<String, AccountContactRelation> contactAcrs = duplicateContactIdToACRs.get(duplicateContactId);
            List<HouseholdInformationWrapper> householdPerDuplicateList = new List<HouseholdInformationWrapper>();

            for (String acrAccountId : contactAcrs.keySet()) {
                HouseholdInformationWrapper houseHoldWrapper = new HouseholdInformationWrapper();
                houseHoldWrapper.householdName = contactAcrs.get(acrAccountId).Account.Name;
                houseHoldWrapper.householdDetails = new List<Contact>();

                for (AccountContactRelation acrVar : allHouseholdsToConstituents.get(acrAccountId)) {
                    //do not include a child record in household list
                    if(acrVar.Contact.RecordType.DeveloperName != 'Child'){
                        houseHoldWrapper.householdDetails.add(acrVar.Contact);
                    }
                }

                householdPerDuplicateList.add(houseHoldWrapper);
            }

            duplicateContactWrapperRecord.householdInformation = householdPerDuplicateList;
            duplicateContactIdToWrapper.put(duplicateContactId, duplicateContactWrapperRecord);
        }
        //finally loop through entries from ui and add corresponding records
        //map unique key to list of Map<duplicateContactId,DuplicateContactWrapper>
        Map<String, DuplicateEntryWrapper> outputMap = new Map<String, DuplicateEntryWrapper>();
        List<Map<String, Map<String, DuplicateContactWrapper>>> output = new List<Map<String, Map<String, DuplicateContactWrapper>>>();
        for (String uniqueId : duplicateContactUniqueIdToContactId.keySet()) {
            DuplicateEntryWrapper dupEntryWrapper = new DuplicateEntryWrapper();
            dupEntryWrapper.name = constituentType == 'parent' ? duplicateUniqueIdToConstituentInformation.get(uniqueId).ParentFullName : duplicateUniqueIdToConstituentInformation.get(uniqueId).TrustedFullName;
            dupEntryWrapper.uniqueId = uniqueId;
            
            Map<Id, Contact> contactMap = duplicateContactUniqueIdToContactId.get(uniqueId);
            
            Map<String, DuplicateContactWrapper> duplicateWrapperMap = new Map<String, DuplicateContactWrapper>();
            for (Id duplicateContactId : contactMap.keySet()) {
                //check with filtered contact list above(within business license)
                if (duplicateContactIdToACRs.containsKey(duplicateContactId)) {
                    duplicateWrapperMap.put(duplicateContactId,duplicateContactIdToWrapper.get(duplicateContactId));
                }
            }

            dupEntryWrapper.duplicateEntries = duplicateWrapperMap;
            outputMap.put(uniqueId, dupEntryWrapper);
        }
        
        return outputMap;
    }

    public static Object updateExistingEnrollment(String childRecordsString, String businessLicenseId, String duplicatesSelectedString){
        if (childRecordsString == null || String.isBlank(childRecordsString)) {
            return null;
        }
        List<ChildInformationWrapper> childRecords = (List<ChildInformationWrapper>) JSON.deserialize(childRecordsString, List<ChildInformationWrapper>.class);
        Map<String, String> selectedDuplicatesMap = !String.isBlank(duplicatesSelectedString) ? (Map<String, String>) JSON.deserialize(duplicatesSelectedString, Map<String, String>.class): new Map<String, String>();
        Map<String, String> selectedDuplicatesEnrollmentIdMap = new Map<String, String>();

        //check for status change
        //if status change do not pass down an enrollment Id, update current enrollment and set the end date
        //if No Status change, send Id back to the IP

        Set<Id> selectedDuplicateContactIds = new Set<Id>();
        Map<String, ChildInformationWrapper> uniqueIdToChildInformation = new Map<String, ChildInformationWrapper>();
        // Map<String, Id> uniqueIdToContactId = new Map<String, Id>();
        //Compile Child entries with childId to check for status change too
        List<ChildInformationWrapper> childEntriesWithId = new List<ChildInformationWrapper>();

        if (selectedDuplicatesMap != null && !selectedDuplicatesMap.isEmpty()) {
            for(String key : selectedDuplicatesMap.keySet()) {
                selectedDuplicateContactIds.add(selectedDuplicatesMap.get(key));
            } 
        }

        for (ChildInformationWrapper childInformation : childRecords) {
            uniqueIdToChildInformation.put(childInformation.childUniqueId, childInformation);
            if(!String.isBlank(childInformation.childId)) {
                //add to Id list to get enrollment recordsfor child entries with childId
                selectedDuplicateContactIds.add(childInformation.childId);
                childEntriesWithId.add(childInformation);
            }
        }
        //query Enrollments
        Map<Id,Enrollment__c> relatedEnrollmentRecords = new Map<Id,Enrollment__c>([SELECT 
                                                                                    Id, 
                                                                                    Name,
                                                                                    End_Date__c,
                                                                                    EnrollmentAward__c,
                                                                                    Partnership__c,
                                                                                    Start_Date__c,
                                                                                    Program_Name__c,
                                                                                    Program_Parent_Aware_Rating__c,
                                                                                    Program_Type__c,
                                                                                    Active__c,
                                                                                    Unique_Identifier__c,
                                                                                    Business_License__c, 
                                                                                    Child__c,
                                                                                    Child__r.AccountId,
                                                                                    Child__r.FirstName,
                                                                                    Child__r.LastName,
                                                                                    Child__r.Birthdate,
                                                                                    Status__c,
                                                                                    Termination_Date__c
                                                                                FROM Enrollment__c 
                                                                                WHERE Business_License__c = :businessLicenseId
                                                                                AND Child__c in :selectedDuplicateContactIds
                                                                                // AND (Status__c = 'Enrolled' OR Status__c = 'Paused' OR Status__c = 'Not Started') 
                                                                                // AND Start_Date__c <= TODAY 
                                                                                // AND (End_Date__c = NULL)
                                                                                AND Child__r.Program_Participation__c = 'Enrollment and Attendance'
                                                                                ORDER BY CreatedDate DESC
                                                                            ]);

            //map each enrollment records to corresponding contactId
            Map<Id, Enrollment__c> contactToEnrollmentRecord = new Map<Id, Enrollment__c>();

            for(Id enrollmentId : relatedEnrollmentRecords.keySet()) {
                if(!contactToEnrollmentRecord.containsKey(relatedEnrollmentRecords.get(enrollmentId).Child__c)) contactToEnrollmentRecord.put(relatedEnrollmentRecords.get(enrollmentId).Child__c, relatedEnrollmentRecords.get(enrollmentId));
            }

            List<Enrollment__c> enrollmentsToUpdate = new List<Enrollment__c>();

            //now check for status change.
            //Scenarios:
            //if initial record is not started and start date from ui is now today or in the past, send record Id and update end date of initial
            //if initial record is enrolled and start date is now in the future, then update the current record end date and send down the enrollmentId
            if (selectedDuplicatesMap != null && !selectedDuplicatesMap.isEmpty()) {
                for(String uniqueId : selectedDuplicatesMap.keySet()) {
                    String duplicateContactId = selectedDuplicatesMap.get(uniqueId);
                    if(contactToEnrollmentRecord.containsKey(duplicateContactId)){
                        //check status change here
                        Enrollment__c existingEnrollment = contactToEnrollmentRecord.get(duplicateContactId);
                        ChildInformationWrapper childInformation =  uniqueIdToChildInformation.get(uniqueId);
                        if (existingEnrollment.Status__c != 'Ended'){
                            if(existingEnrollment.End_Date__c ==null && existingEnrollment.Status__c == 'Not Started' 
                            && (existingEnrollment.Start_Date__c != Date.valueOf(childInformation.childStartDate) && Date.valueOf(childInformation.childStartDate) <= Date.today())){
                                selectedDuplicatesEnrollmentIdMap.put(uniqueId, existingEnrollment.Id);
                            }
                            else if(existingEnrollment.End_Date__c ==null &&  existingEnrollment.Status__c == 'Enrolled' 
                            && (existingEnrollment.Start_Date__c != Date.valueOf(childInformation.childStartDate) && Date.valueOf(childInformation.childStartDate) > Date.today())){
                                existingEnrollment.End_Date__c = Date.today();
                                enrollmentsToUpdate.add(existingEnrollment);
                            }
                            else if(existingEnrollment.End_Date__c ==null && existingEnrollment.Status__c == 'Enrolled' 
                            && (existingEnrollment.Start_Date__c != Date.valueOf(childInformation.childStartDate) && Date.valueOf(childInformation.childStartDate) <= Date.today())
                            || (childInformation.childEndDate != null && existingEnrollment.Termination_Date__c != Date.valueOf(childInformation.childEndDate))){
                                //if status is unchanged and still date is different, we want to update the record so we send down the record Id 
                                selectedDuplicatesEnrollmentIdMap.put(uniqueId, existingEnrollment.Id);
                            }
                            else {
                                //send the id back to the IP if no status change
                                //avoid sending if enrollment is ended or end date has a value
                                if (existingEnrollment.End_Date__c == null) {
                                    selectedDuplicatesEnrollmentIdMap.put(uniqueId, existingEnrollment.Id);
                                }
                            }
                        }
                        
                    }                
                }
            }
            //if entry of child already with child Id triggers a status change, update it also
            for (ChildInformationWrapper childInformation : childEntriesWithId) {
                Enrollment__c existingEnrollment = relatedEnrollmentRecords.get(childInformation.enrollmentId);
                if (existingEnrollment != null) {
                    if(existingEnrollment.Status__c == 'Not Started' 
                    && (existingEnrollment.Start_Date__c != Date.valueOf(childInformation.childStartDate) && Date.valueOf(childInformation.childStartDate) <= Date.today())){
                        //we want to replace the enrollmentId with an empty one so the IP creates a new one
                        selectedDuplicatesEnrollmentIdMap.put(childInformation.childUniqueId, existingEnrollment.Id);
                    }
                    else if(existingEnrollment.Status__c == 'Enrolled' 
                    && (existingEnrollment.Start_Date__c != Date.valueOf(childInformation.childStartDate) && Date.valueOf(childInformation.childStartDate) > Date.today())){
                        existingEnrollment.End_Date__c = Date.today();
                        enrollmentsToUpdate.add(existingEnrollment);
                        //we want to replace the enrollmentId with an empty one so the IP creates a new one
                        selectedDuplicatesEnrollmentIdMap.put(childInformation.childUniqueId, '');
                    }
                }
            }

            try{
                 //update enrollment records
                update enrollmentsToUpdate;
            }
            catch(Exception ex){
                System.debug(ex.getMessage());
                Logger.Instance.logErrorWithRT(ex, 'Error updating enrollment records. '+ex.getMessage(), 'AttendanceUtilities','updateExistingEnrollment',Logger.LOG_TYPES.Attendance);
            }
            finally {
                Logger.Instance.push();
            }
            return selectedDuplicatesEnrollmentIdMap;
    }

    public static void updateMapValuesWithList(Map<String, SObject> mapToUpdate, List<SObject> updatedList) {
        if (mapToUpdate == null || updatedList == null) {
            throw new IllegalArgumentException('The map or list provided cannot be null.');
        }
        
        if (mapToUpdate.size() != updatedList.size()) {
            throw new IllegalArgumentException('The size of the map and the list must be equal.');
        }
        
        Integer i = 0;
        for (String key : mapToUpdate.keySet()) {
            mapToUpdate.put(key, updatedList[i]);
            i++;
        }
    }

    public static Boolean emailAddressIsValid(String email) {

		if (String.isEmpty(email)) return true;

		Boolean isValid = true;

		// Regex source: http://www.regular-expressions.info/email.html
		String emailRegex = '^[a-zA-Z0-9._|\\\\%⌗~`=?&/$^*!}{+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$'; 

		Pattern MyPattern = Pattern.compile(emailRegex);

		Matcher MyMatcher = MyPattern.matcher(email);

		if (!MyMatcher.matches()) 

		    isValid = false;

		return isValid;	
    } 

    public static String sanitizeInput(String input) {
        if (input == null) return '';
        // Keep only alphanumeric characters and hyphens
        return input.replaceAll('[^a-zA-Z0-9\\-]', '');
    }
 
    //----------------------------------------------------- CLASSES ------------------------------------------------- //

    /**
    * @description Class for returning the results of a sharing record creation operation.
    */
    global class ShareRequestResult{
        public boolean success;
        public sObject shareRecord;
        public string message = ''; 
        public string recordObjectType;
        public string sharedToType;
        public object sharedTo;
        public object record;
        public dateTime shareCreated = dateTime.now();
        public string invokedBy;
        public user runningUser;


        public ShareRequestResult(Database.SaveResult saveResult, sObject shareRecord, object sharedTo, object record, user runningUser){
            this.success = saveResult.isSuccess();
            //this.sharedRecordId =  shareRecord.get('ParentId');
            //this.shareTarget = shareRecord.get('UserOrGroupId');
            this.shareRecord = shareRecord;
            id recordObjectTypeId = (Id) shareRecord.get('ParentId');
            id sharedToObjectTypeId = (Id) shareRecord.get('UserOrGroupId');

            this.recordObjectType = String.valueOf(recordObjectTypeId.getSobjectType());
            this.sharedToType = String.valueOf(sharedToObjectTypeId.getSObjectType());

            this.sharedTo = sharedTo != null ? sharedTo : 'Unresolved';
            this.record = record != null ? record : 'Unresolved';
            this.runningUser = runningUser != null ? runningUser : [SELECT Username, firstname, lastname, email FROM USER WHERE Id = :UserInfo.getUserId()];

            if(this.success){
                this.message = 'Record Shared Successfully';
            }else{
                for(Database.Error thisError : saveResult.getErrors()) {

                    // Check if the error is related to trival access level.
                    // Access level must be more permissive than the object's default.
                    // These sharing records are not required and thus an insert exception is acceptable.
                    if(thisError.getStatusCode() == StatusCode.FIELD_FILTER_VALIDATION_EXCEPTION  &&  
                       thisError.getMessage().contains('AccessLevel')){
                        
                        if(this.success == null) this.success = true; //can only set to true if it hasn't already been set to false
                        this.message = 'User already has at least this level of access. This error is expected and can be disregarded. ' + thisError.getStatusCode() + ': ' + thisError.getMessage();
                        break; 
                    }else{                    
                        this.message += thisError.getStatusCode() + ': ' + thisError.getMessage();
                        this.success = false;

                    }
                }
            }
            try{
                //throw a phone error so we can get the stack trace so we know what chain of events led to this sharing rule being created.
                throw new ApplicationException('Expected Error');
            }catch(Exception ex){
                list<string> stackCalls = ex.getStackTraceString().split('\\n');
                this.invokedBy = String.join(stackCalls,' <-- Called From: ');

                //dont log these errors. These are merely informative that can be logged later if a real error happens. This error is just used to get the stack trace string.
                //Logger.Instance.logErrorWithRT(ex, 'Getting the Error while calling ShareRequestResult', 'AttendanceUtilities','ShareRequestResult',Logger.LOG_TYPES.Attendance);
			}
        }
    }

    /**
    * @description Overall roster information that is returned to the attendance LWCs that contain the list of attendees, the applicable date, business license 
    * information and other relevant data to rostering/attendance.
    */
    global class RosterWrapper{
        @AuraEnabled
        public id businessLicenseId;
        @AuraEnabled
        public string businessLicenseName;
        @AuraEnabled
        public string businessLicenseProgramName;
        @AuraEnabled
        public date rosterDate;
        @AuraEnabled
        public string dateLabel;
        @AuraEnabled
        public integer numAttendees = 0;
        @AuraEnabled
        public integer numCheckedIn = 0;
        @AuraEnabled
        public integer numCheckedOut = 0;
        @AuraEnabled
        public boolean dataSourceIsIntegration = false;
        @AuraEnabled
        public string dataIntegrationSourceName;
        @AuraEnabled
        public Business_License_Integration_Tracker__c businessLicenseIntegrationTracker;
        @AuraEnabled
        public datetime dataIntegrationLastUpdate;

        
        @AuraEnabled
        public list<AttendeeWrapper> attendees = new list<AttendeeWrapper>();

        public RosterWrapper(Id businessLicenseId, Date rosterDate, list<AttendeeWrapper> Attendees){
            this.businessLicenseId = businessLicenseId;
            this.rosterDate = rosterDate;

            Datetime dt = Datetime.newInstance(rosterDate.year(),rosterDate.month(),rosterDate.day());
            this.dateLabel = dt.format('MMM d, yyyy');

            this.Attendees = Attendees;
            this.numAttendees = Attendees.size();
            for(AttendeeWrapper thisAttendee : this.Attendees){
                if(thisAttendee?.checkedIn) this.numCheckedIn++;
                else this.numCheckedOut++;
            }
        }
    }

    /**
    * @description Wrapper class for the Enrollment__c object. An enrollment connects a contact/student to a business.
    */
    global class EnrollmentWrapper{
        @AuraEnabled
        public Enrollment__c record;

        public EnrollmentWrapper(Enrollment__c thisEnrollment){
            this.record = thisEnrollment;
        }
    }

    /**
    * @description Wrapper class that contains information relevant to attendance tracking. It's a combination of an Attendance__c and Contact object containing information
    * about the current check in status for that person for a given day.
    */
    global class AttendeeWrapper{
        @AuraEnabled
        public string uniqueIdKey;
        @AuraEnabled
        public Attendance__c attendanceRecord;
        @AuraEnabled
        public Contact attendeeRecord;
        @AuraEnabled
        public boolean isNew;
        @AuraEnabled
        public string firstName;
        @AuraEnabled
        public string lastName;
        @AuraEnabled
        public date birthDate;
        @AuraEnabled
        public boolean checkedIn;
        @AuraEnabled
        public boolean checkedOut;
        @AuraEnabled
        public dateTime checkedInTime;
        @AuraEnabled
        public dateTime checkedOutTime;
        @AuraEnabled
        public string checkedInBy;
        @AuraEnabled
        public string checkedOutBy;
        @AuraEnabled
        public integer numOpenCheckIns;
        @AuraEnabled
        public integer checkedInMinutes;
        @AuraEnabled
        public integer totalCheckins;
        @AuraEnabled
        public id operatingContact; //the contact to use as the Checked_In_By_Contact__c / Checked_Out_By_Contact__c
        @AuraEnabled
        public list<AttendanceTrackingResultWrapper> attendanceTrackingSaveResults = new list<AttendanceTrackingResultWrapper>();
        @AuraEnabled
        //this has to be transient because if not, when incoming and attempting to deserialize we get error: "QueryResult must start with '". Do not attempt to provide this
        //property to an AuraEnabled method and deserialize it. It won't work. It can be SENT to an LWC because transient only seems to apply to VF pages
        public transient list<Contact> parentsWithEmail = new list<Contact>(); 
        @AuraEnabled
        public boolean hasParentWithEmail = false;

        //Set this when submitted to setAttendanceTrackingStatus method to update the time. As this isn't set on construction/instantiation it prevents unmodified
        //objects from causing check in/out operations. 
        @AuraEnabled
        public dateTime updatedCheckInTime; 

        //Set this when submitted to setAttendanceTrackingStatus method to update the time. As this isn't set on construction/instantiation it prevents unmodified
        //objects from causing check in/out operations. 
        @AuraEnabled
        public dateTime updatedCheckOutTime;     
        
        @AuraEnabled 
        public boolean isOpen;
        
        public AttendeeWrapper(Contact thisContact, Attendance__c thisAttendance){
            this.uniqueIdKey = thisContact.Id + '-' + thisAttendance.Enrollment__c;
            this.attendanceRecord = thisAttendance;
            this.attendeeRecord = thisContact;
            this.isNew = thisAttendance.Id == null ? true : false;
            this.firstName = thisContact?.Firstname;
            this.lastName = thisContact?.LastName;
            this.birthDate = thisContact?.Birthdate;
            this.checkedIn = thisAttendance?.Is_Checked_In__c;
            this.checkedOut = thisAttendance?.Is_Checked_Out__c;
            this.checkedIntime = thisAttendance?.First_Check_In__c;
            this.checkedOuttime = thisAttendance?.Last_Checkout__c;
            this.numOpenCheckIns = (integer) thisAttendance?.Number_Of_Open_Checkins__c;
            this.checkedInMinutes = (integer) thisAttendance?.Total_Minutes__c;
            this.totalCheckins = (integer) thisAttendance?.Number_of_Check_in_Events__c;
            this.isOpen = thisAttendance.Has_Open_Check_In__c;
            if(!thisAttendance.Attendance_Tracking__r.isEmpty()){
                this.checkedInBy = thisAttendance.Attendance_Tracking__r[0]?.Checked_In_By__r?.firstname + ' ' + thisAttendance.Attendance_Tracking__r[0]?.Checked_In_By__r?.lastname;
                this.checkedOutBy = thisAttendance.Attendance_Tracking__r[0]?.Checked_Out_By__r?.firstname + ' ' + thisAttendance.Attendance_Tracking__r[0]?.Checked_Out_By__r?.lastname;
            }
            this.attendanceTrackingSaveResults = new list<AttendanceTrackingResultWrapper>();
          
            //this.updatedCheckInTime = this.checkedIntime != null ? this.checkedIntime : Datetime.newInstance(this.attendanceRecord.Schedule_Date__c, Time.newInstance(9, 0, 0, 0));
            //this.updatedCheckOutTime = this.checkedOuttime != null ? this.checkedOuttime: Datetime.newInstance(this.attendanceRecord.Schedule_Date__c, Time.newInstance(17, 0, 0, 0));
        }

        public AttendeeWrapper(){}
    }

    //container for all attendance tracking events for a given person for a day
    global class AttendanceTrackingWrapperContainer {
        @AuraEnabled
        public Attendance__c attendanceRecord = new Attendance__c();

        @AuraEnabled
        public Contact contact = new Contact();

        @AuraEnabled
        public list<AttendanceTrackingWrapper> tracking = new list<AttendanceTrackingWrapper>();

        //future use
        @AuraEnabled
        public boolean allowDelete = true;

        @AuraEnabled
        public boolean allowUpdate = true;
    }

    global class AttendanceTrackingWrapper{
        @AuraEnabled
        public Attendance_Tracking__c attendanceTrackingRecord;
        @AuraEnabled
        public Id recordId;
        @AuraEnabled 
        public string Name;
        @AuraEnabled
        public boolean checkedIn;
        @AuraEnabled
        public boolean checkedOut;
        @AuraEnabled
        public dateTime checkedInTime;
        @AuraEnabled
        public dateTime checkedOutTime;
        @AuraEnabled
        public string checkedInBy;
        @AuraEnabled
        public string checkedOutBy;
        @AuraEnabled
        public integer numOpenCheckIns;
        @AuraEnabled
        public integer checkedInMinutes;
        @AuraEnabled
        public boolean preventUpdate;
        @AuraEnabled
        public boolean preventDelete;
        @AuraEnabled
        public boolean isNew;      
        @AuraEnabled
        public boolean dataSourceIsIntegration = false;
        @AuraEnabled
        public string  dataIntegrationSourceName;
        @AuraEnabled
        public string  dataIntegrationSourceId;  

        public AttendanceTrackingWrapper(Attendance_Tracking__c trackingRecord){
            this.recordId = trackingRecord.Id;
            this.attendanceTrackingRecord = trackingRecord;
            this.checkedIn = trackingRecord?.Checked_In__c;
            this.checkedOut = trackingRecord?.Checked_Out__c;
            this.checkedInBy = trackingRecord?.Checked_In_By__r.Name;
            this.checkedOutBy = trackingRecord?.Checked_Out_By__r.Name;
            this.checkedIntime = trackingRecord?.Check_In__c;
            this.checkedOuttime = trackingRecord?.Check_Out__c;
            this.checkedInMinutes = (integer) trackingRecord?.Stay_Length_Minutes__c;
            this.preventUpdate = false;
            this.preventDelete = false;
            this.isNew = trackingRecord.Id != null ? false : true;
            this.dataSourceIsIntegration = !String.isEmpty(trackingRecord?.CCMS_SourceId__c);
            this.dataIntegrationSourceName = dataSourceIsIntegration ? trackingRecord?.CCMS_SourceName__c : 'None';
            this.dataIntegrationSourceId = trackingRecord?.CCMS_SourceId__c;
        }
        public AttendanceTrackingWrapper(){}
    }

    public class PinOperationResponse{
        @AuraEnabled
        public boolean success = true;

        @AuraEnabled
        public string message = 'Operation Successful';

        @AuraEnabled
        public Contact contact;

        @AuraEnabled
        public list<AttendanceUtilities.EnrollmentWrapper> enrollments = new list<AttendanceUtilities.EnrollmentWrapper>();

        @AuraEnabled
        public string action;

        @AuraEnabled
        public string pinType;

        public PinOperationResponse(string actionName){
            this.action = actionName;
        }
    }

    global class ConstituentInformationWrapper{
        @AuraEnabled
        public String guardianId;
        @AuraEnabled
        public String trustedId;
        @AuraEnabled
        public String guardianLastName;	//Rooney
        @AuraEnabled
        public String guardianFirstName;	//Wayne
        @AuraEnabled
        public String trustedFirstName;	//Rooney
        @AuraEnabled
        public String trustedLastName;	//Wayne
        @AuraEnabled
        public String ParentFullName;
        @AuraEnabled
        public String TrustedFullName;
    }

    // global class ConstituentAddressWrapper {
    //     @AuraEnabled
    //     public String guardianFullAddress;	//122 Serenity Ct, Avon, MN 56310
    //     @AuraEnabled
    //     public String GuardianAddressTypeAhead;	//122 Serenity Ct, Avon, MN 56310
    //     @AuraEnabled
    //     public String guardianCountry;	//US
    //     @AuraEnabled
    //     public String guardianCity;	//Avon
    //     @AuraEnabled
    //     public String guardianState;	//MN
    //     @AuraEnabled
    //     public String guardianZipCode;	//56310
    //     @AuraEnabled
    //     public String guardianStreetAddress;	//122 Serenity Ct
    // }

    global class ChildInformationWrapper {
        @AuraEnabled
        public String childId;
        
        @AuraEnabled
        public String childFirstName;

        @AuraEnabled
        public String childLastName;

        @AuraEnabled
        public String childDateOfBirth;

        @AuraEnabled
        public String ChildFullName;

        @AuraEnabled 
        public String childStartDate;

        @AuraEnabled
        public String childEndDate;

        @AuraEnabled
        public String childUniqueId;

        @AuraEnabled
        public String enrollmentId;
    }

    global class DuplicateEntryWrapper {
        @AuraEnabled
        public String name; 

        @AuraEnabled
        public String uniqueId; 

        @AuraEnabled
        public Map<String, DuplicateContactWrapper> duplicateEntries;
    }

    global class DuplicateContactWrapper {
        @AuraEnabled
        public String Id;

        @AuraEnabled
        public Contact contactRecord; 

        @AuraEnabled
        public Boolean selected = false; 
        
        @AuraEnabled
        public List<HouseholdInformationWrapper> householdInformation;

        @AuraEnabled
        public Boolean enrollmentExpired;

        @AuraEnabled
        public Boolean enrollmentPaused;
    }

    global class HouseholdInformationWrapper {
        @AuraEnabled
        public String householdName; 

        @AuraEnabled
        public List<Contact> householdDetails;
    }
    
    public class AttendanceTrackingResultWrapper {
        @AuraEnabled
        public Attendance_Tracking__c trackingRecord { get; set; }
        @AuraEnabled
        public Boolean isSuccess { get; set; }
        @AuraEnabled
        public String errorMessage { get; set; }
        @AuraEnabled 
        public String friendlyError {get; set; }
        
        // Constructor
        public AttendanceTrackingResultWrapper(Attendance_Tracking__c trackingRecord, Boolean isSuccess, String errorMessage) {
            this.trackingRecord = trackingRecord;
            this.isSuccess = isSuccess;
            this.errorMessage = errorMessage;
            this.friendlyError = ErrorMessageService.getUserFriendlyErrorMessage(errorMessage);
        }
    }

    public class LogicException extends Exception {}
    public class ApplicationException extends Exception {}
    public class DataException extends Exception {}
}