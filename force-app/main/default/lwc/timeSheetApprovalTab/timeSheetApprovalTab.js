import { LightningElement, track, wire } from 'lwc';
import getProcessInstanceWorkItem from '@salesforce/apex/ApprovalProcessController.getProcessInstanceWorkItem';
import { NavigationMixin } from 'lightning/navigation';
import Id from "@salesforce/user/Id";
export default class TimeSheetApprovalTab extends LightningElement {
    processInstanceData;
    baseURL;
    customURL;
    currentUserId = Id;
    uiMessage;
    displayError = false;
    showData= false;

    @wire(getProcessInstanceWorkItem, {userID : '$currentUserId'})
    wiredRecord({ data, error }) {
        if(data && data.length>0){
            this.processInstanceData = data;
            this.showData = true;
            this.displayError = false;
            this.uiMessage = '';
        } else if (error){
            this.uiMessage = 'Please Contact System admin for access';
            this.displayError = true;
            this.showData = false;
        } else {
            this.uiMessage = 'There are no Pending Approvals';
            this.displayError = true;
            this.showData = false;
        }
    }

    connectedCallback() {
        this.baseURL = window.location.origin;
    }

    navigateToTimesheet(event) {                                                      
        const processInstanceWorkItemId = event.currentTarget.dataset.recordid;
        this.customURL = this.baseURL+'/lightning/r/ProcessInstanceWorkitem/'+processInstanceWorkItemId+'/view'; 
    }  
}