import { LightningElement, track, wire } from 'lwc';
import getTimerInitData from '@salesforce/apex/TimesheetTimerController.getTimerInitData';
import startTimer from '@salesforce/apex/TimesheetTimerController.startTimer';
import stopTimer from '@salesforce/apex/TimesheetTimerController.stopTimer';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import TIMESHEET_LINE_ITEM_OBJECT from '@salesforce/schema/Timesheet_Line_Item__c';
import ACTIVITY_CATEGORY_FIELD from '@salesforce/schema/Timesheet_Line_Item__c.Activity__c';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TimesheetTimer extends LightningElement {
    @track isLoading = true;
    @track isRunning = false;
    @track formattedTime = '00:00:00';
    
    @track selectedProject = '';
    @track selectedActivity = '';
    @track projectOptions = [];
    @track activityOptions = [];
    
    activeProjectName = '';
    activeActivityName = '';
    
    employeeId;
    activeLineItemId;
    startTime;
    timerInterval;

    @wire(getObjectInfo, { objectApiName: TIMESHEET_LINE_ITEM_OBJECT })
    objectInfo;

    @wire(getPicklistValues, { 
        recordTypeId: '$objectInfo.data.defaultRecordTypeId', 
        fieldApiName: ACTIVITY_CATEGORY_FIELD 
    })
    wiredActivityPicklistValues({ error, data }) {
        if (data) {
            this.activityOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
        }
    }

    connectedCallback() {
        this.loadInitData();
    }

    disconnectedCallback() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
        }
    }

    loadInitData() {
        this.isLoading = true;
        getTimerInitData()
            .then(result => {
                this.employeeId = result.employeeId;
                if (result.projects) {
                    this.projectOptions = result.projects.map(pe => ({
                        label: pe.Project__r.Name,
                        value: pe.Project__c
                    }));
                }
                
                if (result.activeTimer) {
                    this.activeLineItemId = result.activeTimer.Id;
                    this.activeProjectName = result.activeTimer.Project__r.Name;
                    this.activeActivityName = result.activeTimer.Activity__c;
                    this.startTime = new Date(result.activeTimer.Start_Time__c).getTime();
                    this.startClock();
                }
                this.isLoading = false;
            })
            .catch(error => {
                console.error(error);
                // Fail silently if not setup, so it doesn't crash the homepage
                this.isLoading = false;
            });
    }

    get startDisabled() {
        return !this.selectedProject || !this.selectedActivity;
    }

    get timerClass() {
        return this.isRunning ? 'running' : '';
    }

    handleProjectChange(event) {
        this.selectedProject = event.detail.value;
    }

    handleActivityChange(event) {
        this.selectedActivity = event.detail.value;
    }

    handleStart() {
        this.isLoading = true;
        startTimer({ 
            employeeId: this.employeeId, 
            projectId: this.selectedProject, 
            activityName: this.selectedActivity 
        })
        .then(result => {
            this.activeLineItemId = result.Id;
            this.activeProjectName = result.Project__r.Name;
            this.activeActivityName = result.Activity__c;
            this.startTime = new Date(result.Start_Time__c).getTime();
            this.startClock();
            this.isLoading = false;
        })
        .catch(error => {
            this.showToast('Error', error.body?.message || 'Failed to start timer', 'error');
            this.isLoading = false;
        });
    }

    handleStop() {
        this.isLoading = true;
        stopTimer({ lineItemId: this.activeLineItemId })
        .then(() => {
            this.stopClock();
            this.showToast('Success', 'Time logged successfully!', 'success');
            
            // Reset state
            this.activeLineItemId = null;
            this.selectedProject = '';
            this.selectedActivity = '';
            this.formattedTime = '00:00:00';
            this.isLoading = false;
        })
        .catch(error => {
            this.showToast('Error', error.body?.message || 'Failed to stop timer', 'error');
            this.isLoading = false;
        });
    }

    startClock() {
        this.isRunning = true;
        this.updateTimeDisplay();
        this.timerInterval = setInterval(() => {
            this.updateTimeDisplay();
        }, 1000);
    }

    stopClock() {
        this.isRunning = false;
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
        }
    }

    updateTimeDisplay() {
        const now = new Date().getTime();
        const diff = Math.max(0, now - this.startTime);
        
        let seconds = Math.floor((diff / 1000) % 60);
        let minutes = Math.floor((diff / (1000 * 60)) % 60);
        let hours = Math.floor((diff / (1000 * 60 * 60)));
        
        this.formattedTime = 
            this.pad(hours) + ':' + 
            this.pad(minutes) + ':' + 
            this.pad(seconds);
    }

    pad(val) {
        return val < 10 ? '0' + val : val;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}
