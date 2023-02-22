@isTest
public class PostInstallScriptTest {
    
    @isTest
    static void doInstallTest(){
        List<User> userList = [Select Id, Profile.Name from User where Profile.UserLicense.Name = 'Salesforce' AND IsActive = true];
        List<Id> idList = new List<Id>();
        for(User u : userList){
            idList.add(u.Id);
        }
		List<PermissionSetAssignment> psaList1 = [Select Id, AssigneeId from PermissionSetAssignment where PermissionSet.Name = 'TimeSheet_User' OR PermissionSet.Name = 'Time_Sheet_HR_Admin'];
        System.assertEquals(0, psaList1.size(), 'The psaList1 size should be zero');
        PostInstallScript pis = new PostInstallScript();
        Test.testInstall(pis, null);
        //Test.testInstall(pis,  new Version(1, 0));
        List<PermissionSetAssignment> psaList2 = [Select Id, AssigneeId from PermissionSetAssignment where PermissionSet.Name = 'TimeSheet_User' OR PermissionSet.Name = 'Time_Sheet_HR_Admin'];
        System.assert( psaList2.size() > 0, 'The psaList2 size should be greater than zero');
        System.assertEquals(userList.size(), psaList2.size() , 'The psaList2 size should be equal to userList size');
    }
}