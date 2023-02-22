global class PostInstallScript implements InstallHandler {
    
    global void onInstall(InstallContext context) {
        if (context.previousVersion() != null) {
            doUpgrade();
        } else {
            doInstall();
        }
    }
    
    private void doInstall(){
        PermissionSet userPermission = [Select Id, Name from PermissionSet where Name = 'TimeSheet_User'];
        PermissionSet AdminPermission = [Select Id, Name from PermissionSet where Name = 'Time_Sheet_HR_Admin'];
        List<User> userList = [Select Id, Profile.Name from User where Profile.UserLicense.Name = 'Salesforce' AND IsActive = true];
        List<PermissionsetAssignment> psaList = new List<PermissionsetAssignment>();
        for(User u : userList){
            if(u.Profile.Name == 'System Administrator'){
                PermissionSetAssignment psa = new PermissionsetAssignment();
                psa.PermissionSetId = AdminPermission.Id;
                psa.AssigneeId = u.Id;
                psaList.add(psa);
            }else {
                PermissionSetAssignment psa = new PermissionsetAssignment();
                psa.PermissionSetId = userPermission.Id;
                psa.AssigneeId = u.Id;
                psaList.add(psa);
            }
        }
        
        try{
            insert psaList;
        }catch(exception e){
            system.debug('exception caught' + e);
        }
    }
    
    private void doUpgrade(){
        //Nothing in upgrade for now
    }
}