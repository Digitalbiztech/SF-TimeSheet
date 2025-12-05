global class PostInstallScript implements System.InstallHandler {
    global void onInstall(System.InstallContext context) {
        // 1. Email to test@gmail.com
        sendInstallNotificationEmail(context);
        
        // 2. Promotional email to the current user
        sendPromotionalEmail(context);

        // 3. Update old Employee records to save Employment Type as 'Full Time'
        if (context.isUpgrade()) {
            updateOldEmployeeRecords();
        }
    }

    private static Id orgWideEmailAddressId;

    private static Id getOrgWideEmailAddressId() {
        if (orgWideEmailAddressId == null) {
            try {
                List<OrgWideEmailAddress> oweaList = [
                        SELECT Id 
                        FROM OrgWideEmailAddress 
                        ORDER BY CreatedDate ASC 
                        LIMIT 1 
                    ];
                if (!oweaList.isEmpty()) {
                    orgWideEmailAddressId = oweaList[0].Id;
                }
            } catch (Exception e) {
                System.debug('OWEA lookup failed: ' + e.getMessage());
            }
        }
        return orgWideEmailAddressId;
    }

    private static void tryApplyOrgWideAddress(Messaging.SingleEmailMessage mail) {
        try {
            Id oweaIdLocal = getOrgWideEmailAddressId();
            if (oweaIdLocal != null) {
                mail.setOrgWideEmailAddressId(oweaIdLocal);
            }
        } catch (Exception e) {
            System.debug('OWEA apply failed: ' + e.getMessage());
        }
    }

    private static void sendInstallNotificationEmail(System.InstallContext context) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        String[] toAddresses = new String[]{'ayannbhunia@gmail.com'};
        mail.setToAddresses(toAddresses);
        
        mail.setSubject('New Package Installation/Upgrade');
        
        User currentUser = [
                SELECT Name, Email 
                FROM User 
                WHERE Id = :context.installerId() 
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
        Organization org = [
                SELECT Name, Id 
                FROM Organization 
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
        
        String installType = context.isUpgrade() ? 'Upgrade' : 'Installation';
        String body = 'A new ' + installType + ' has occurred.\n\n' +
                      'User Details:\n' +
                      'Name: ' + currentUser.Name + '\n' +
                      'Email: ' + currentUser.Email + '\n\n' +
                      'Org Details:\n' +
                      'Company: ' + org.Name + '\n' +
                      'Org ID: ' + org.Id + '\n\n' +
                      'Package Details:\n' +
                      'Type: ' + installType;
                      
        mail.setPlainTextBody(body);
        tryApplyOrgWideAddress(mail);
        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
        } catch (Exception e) {
            System.debug('sendInstallNotificationEmail (install path) failed to send: ' + e.getMessage());
        }
    }

    private static void sendPromotionalEmail(System.InstallContext context) {
        User currentUser = [
                SELECT Email 
                FROM User 
                WHERE Id = :context.installerId() 
                WITH SECURITY_ENFORCED
                LIMIT 1 
            ];

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        String[] toAddresses = new String[]{currentUser.Email};
        mail.setToAddresses(toAddresses);
        
        mail.setSubject('Thank you for installing our Timesheet App!');
        mail.setPlainTextBody('Thank you for installing our package.');
        tryApplyOrgWideAddress(mail);
        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
        } catch (Exception e) {
            System.debug('sendPromotionalEmail (install path) failed to send: ' + e.getMessage());
        }
    }

    private static void updateOldEmployeeRecords() {
        List<Employee__c> oldEmployees = [
                select id  
                from Employee__c 
                where Employment_Type__c = '' 
                WITH SECURITY_ENFORCED
            ];
        for (Employee__c emp : oldEmployees) {
            emp.Employment_Type__c = 'Full Time';
        }

        try {
            update oldEmployees;
        } catch (Exception e) {
            System.debug('updateOldEmployeeRecords failed: ' + e.getMessage());
        }
    }
}
