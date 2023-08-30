@isTest
public class EmployeeTriggerHandlerTest {
    
    @isTest
    public static void beforeInsertTest(){
        
        User su = createUser();
        insert su;
        
        User u = createAdminUser();
        insert u;
        
        assignPermissionSetForUser(u);
        
        Employee__c employee1 = createEmployeeForUser(su.Id);
        insert employee1;
        
        Employee__c employee2 = createEmployeeForUser(su.Id);
        
        System.runAs(u){
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
    public static void beforeUpdateTest(){
        
       	User su1 = createUser();
        insert su1;
        
        User su2 = createUser();
        insert su2;
        
		User u = createAdminUser();
        insert u;
        
        assignPermissionSetForUser(u);        
        
        Employee__c employee1 = createEmployeeForUser(su1.Id);
        insert employee1;
        
        Employee__c employee2 = createEmployeeForUser(su2.Id);
        insert employee2;
        
        employee2.User__c = su1.Id;
        
        System.runAs(u){
            Test.startTest();
            try{
                update employee2;
            }catch(DMLException e){
                Assert.areEqual('An Employee with same user already exists', e.getDmlMessage(0), 'Assertion failed for error message when inserting second Employee with same user');
            }  
            Test.stopTest();
        }
    }
    
    private static User createAdminUser(){
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
        u.FirstName = 'fName'+ Datetime.now().format('hh.mm.ss.SSS');
        u.LastName = 'lName' + Datetime.now().format('hh.mm.ss.SSS');
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
    
    private static User createUser(){
        Profile p = [Select Id, Name from Profile where Name = 'Standard Platform User' LIMIT 1];
        
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
        u.FirstName = 'fName'+ Datetime.now().format('hh.mm.ss.SSS');
        u.LastName = 'lName' + Datetime.now().format('hh.mm.ss.SSS');
        u.Phone = '9876543210';
        return u;
    }
    
    private static void assignpermissionSetForUser(User u){
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