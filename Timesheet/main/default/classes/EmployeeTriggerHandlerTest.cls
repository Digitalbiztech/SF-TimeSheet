@isTest
public class EmployeeTriggerHandlerTest {
    
    @testSetup
    public static void setupData(){
        User standardUser = createUser('Standard', 'User');
        insert standardUser;
        
        User standardUser2 = createUser('Standard', 'User2');
        insert standardUser2;
        
        User adminUser = createAdminUser('Admin', 'User');
        insert adminUser;
        
        assignpermissionSetForAdmin(adminUser);
    }
    
    @isTest
    public static void beforeInsertTest(){
        User standardUser = [Select Id, Name from User where FirstName = 'Standard' AND LastName = 'User' LIMIT 1];
        User adminUser = [Select Id, Name from User where FirstName = 'Admin' AND LastName = 'User' LIMIT 1];
        Employee__c employee1 = createEmployeeForUser(standardUser.Id);
        insert employee1;
        
        Employee__c employee2 = createEmployeeForUser(standardUser.Id);
        System.runAs(adminUser){
            Test.startTest();
            try{
                insert employee2;
            }catch(DMLException e){
                Assert.areEqual('An Employee with same user already exists', e.getDmlMessage(0), 'Assertion failed for error message when inserting second Employee with same user');
            }  
            Test.stopTest();
        }
    }
    
    @isTest
    public static void beforeInsertTestWithException(){
        User standardUser = [Select Id, Name from User where FirstName = 'Standard' AND LastName = 'User' LIMIT 1];
        User adminUser = [Select Id, Name from User where FirstName = 'Admin' AND LastName = 'User' LIMIT 1];
        Employee__c employee1 = createEmployeeForUser(standardUser.Id);
        insert employee1;
        
        Employee__c employee2 = createEmployeeForUser(standardUser.Id);
        System.runAs(standardUser){
            Test.startTest();
            try{
                insert employee2;
            }catch(Exception e){
                Assert.areEqual('Script-thrown exception', e.getMessage());
            }  
            Test.stopTest();
        }
    }
    
    @isTest
    public static void beforeUpdateTest(){
        User standardUser = [Select Id, Name from User where FirstName = 'Standard' AND LastName = 'User' LIMIT 1];
        User standardUser2 = [Select Id, Name from User where FirstName = 'Standard' AND LastName = 'User2' LIMIT 1];
        User adminUser = [Select Id, Name from User where FirstName = 'Admin' AND LastName = 'User' LIMIT 1];
        Employee__c employee1 = createEmployeeForUser(standardUser.Id);
        insert employee1;
        
        Employee__c employee2 = createEmployeeForUser(standardUser2.Id);
        insert employee2;
        
        employee2.User__c = standardUser.Id;
        System.runAs(adminUser){
            Test.startTest();
            try{
                update employee2;
            }catch(DMLException e){
                Assert.areEqual('An Employee with same user already exists', e.getDmlMessage(0), 'Assertion failed for error message when inserting second Employee with same user');
            }  
            Test.stopTest();
        }
    }
    
    private static User createAdminUser(String firstName, String lastName){
        Profile p = [Select Id, Name from Profile where Name = 'System Administrator' LIMIT 1];
        
        User u = new User();
        u.Email = 'testEmail@'+ Datetime.now().format('hh.mm.ss.SSS') + '.com';
        u.ProfileId = p.Id;
        u.Username = 'testUserName'+ Datetime.now().format('hh.mm.ss.SSS')+'@testmail.com';
        u.Alias = 'abcd';
        u.CommunityNickname = 'nickName' + Datetime.now().format('hh.mm.ss.SSS');
        u.TimeZoneSidKey = 'America/Los_Angeles';
        u.LocaleSidKey = 'en_US';
        u.EmailEncodingKey='ISO-8859-1';
        u.ManagerId = UserInfo.getUserId();
        u.LanguageLocaleKey='en_US';
        u.FirstName = firstName;
        u.LastName = lastName;
        u.Phone = '9876543210';
        return u;
    }
    
    private static Employee__c createEmployeeForUser(Id userId){
        Employee__c employee = new Employee__c();
        employee.Name = '-';
        employee.First_Name__c = 'fName';
        employee.Last_Name__c = 'lName';
        employee.User__c = userId;
        employee.Email__c = 'testEmail@'+ Datetime.now().format('hh.mm.ss.SSS') + '.com';
        employee.Manager__c = userInfo.getUserId();
        return employee;
    }
    
    private static User createUser(String firstName, String lastName){
        Profile p = [Select Id, Name from Profile where Name = 'Standard User' LIMIT 1];
        
        User u = new User();
        u.Email = 'testEmail@'+ Datetime.now().format('hh.mm.ss.SSS') + '.com';
        u.ProfileId = p.Id;
        u.Username = 'testUserName'+ Datetime.now().format('hh.mm.ss.SSS')+'@testmail.com';
        u.Alias = 'abcd';
        u.CommunityNickname = 'nickName' + Datetime.now().format('hh.mm.ss.SSS');
        u.TimeZoneSidKey = 'America/Los_Angeles';
        u.LocaleSidKey = 'en_US';
        u.EmailEncodingKey='ISO-8859-1';
        u.ManagerId = UserInfo.getUserId();
        u.LanguageLocaleKey='en_US';
        u.FirstName = firstName;
        u.LastName = lastName;
        u.Phone = '9876543210';
        return u;
    }
    
    private static void assignpermissionSetForAdmin(User u){
        Id userId = UserInfo.getUserId();
        User user = [Select Id, Name from User Where Id =: userId];
        
        PermissionSet ps = [Select 
                            Id, 
                            Name 
                            FROM PermissionSet 
                            WHERE Name = 'Timesheet_HR_Admin'];
        System.runAs(user){
            PermissionSetAssignment psa = new PermissionSetAssignment();
        	psa.PermissionSetId = ps.Id;
        	psa.AssigneeId = u.Id;
            insert psa;
        }
    }
}