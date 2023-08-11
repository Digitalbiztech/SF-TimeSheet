import { LightningElement, api, wire, track } from 'lwc';
import getRelatedTimesheets from '@salesforce/apex/TimesheetLineItemController.getTimesheetLineItems';

export default class RelatedTimesheetLineItemsLWC extends LightningElement {

    @api recordId;
    @track timesheetLineItems;

    @wire(getRelatedTimesheets, {processInstanceWorkItemId: '$recordId'}) 
    WireTimesheetLineItems({error, data}){
        if(data){
            let nameUrl;
            let projectUrl;
            let projectName;
            this.timesheetLineItems = data.map(row => { 
                
                nameUrl = `/${row.Id}`;
                if(row.dbt__Project__c != null){
                    projectUrl = `/${row.dbt__Project__c}`;
                    projectName = row.dbt__Project__r.Name;
                } else{
                    projectUrl = null;
                    projectName = null;
                }
                return {...row , nameUrl, projectUrl, projectName}
            })
            this.error = null;
        }else{
            this.error = error;
            this.timesheetLineItems = undefined;
        }
    }
}