import { LightningElement, track, wire, api } from 'lwc';
import getTimerInitData from '@salesforce/apex/TimesheetTimerController.getTimerInitData';
import startTimer from '@salesforce/apex/TimesheetTimerController.startTimer';
import stopTimer from '@salesforce/apex/TimesheetTimerController.stopTimer';
import discardTimer from '@salesforce/apex/TimesheetTimerController.discardTimer';
import updateTimerDescription from '@salesforce/apex/TimesheetTimerController.updateTimerDescription';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import TIMESHEET_LINE_ITEM_OBJECT from '@salesforce/schema/Timesheet_Line_Item__c';
import ACTIVITY_CATEGORY_FIELD from '@salesforce/schema/Timesheet_Line_Item__c.Activity__c';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TimesheetTimer extends LightningElement {
    @api label;
    @api recordId;
    @track isLoading = true;
    @track isRunning = false;
    @track isPendingSave = false;
    @track formattedTime = '00:00:00';
    
    @track selectedProject = '';
    @track selectedActivity = '';
    @track projectOptions = [];
    @track activityOptions = [];
    @track description = '';
    
    activeProjectName = '';
    activeActivityName = '';
    
    employeeId;
    activeLineItemId;
    startTime;
    stopTimeMs;
    timerInterval;
    existingDuration = 0;

    get today() {
        return new Date();
    }

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

    getFieldValue(obj, fieldName) {
        if (!obj) return undefined;
        if (obj[fieldName] !== undefined) return obj[fieldName];
        if (obj['dbt__' + fieldName] !== undefined) return obj['dbt__' + fieldName];
        return undefined;
    }

    getRelValue(obj, relName, fieldName) {
        if (!obj) return undefined;
        let rel = obj[relName] !== undefined ? obj[relName] : obj['dbt__' + relName];
        if (rel) {
            if (rel[fieldName] !== undefined) return rel[fieldName];
            if (rel['dbt__' + fieldName] !== undefined) return rel['dbt__' + fieldName];
        }
        return undefined;
    }

    loadInitData() {
        this.isLoading = true;
        getTimerInitData()
            .then(result => {
                this.employeeId = result.employeeId;
                if (result.projects) {
                    this.projectOptions = result.projects.map(pe => ({
                        label: this.getRelValue(pe, 'Project__r', 'Name'),
                        value: this.getFieldValue(pe, 'Project__c')
                    }));
                }
                
                if (result.activeTimer) {
                    this.activeLineItemId = result.activeTimer.Id;
                    this.activeProjectName = this.getRelValue(result.activeTimer, 'Project__r', 'Name');
                    this.activeActivityName = this.getFieldValue(result.activeTimer, 'Activity__c');
                    this.selectedProject = this.getFieldValue(result.activeTimer, 'Project__c');
                    this.selectedActivity = this.getFieldValue(result.activeTimer, 'Activity__c');
                    this.description = this.getFieldValue(result.activeTimer, 'Description__c') || '';
                    this.startTime = new Date(this.getFieldValue(result.activeTimer, 'Start_Time__c')).getTime();
                    let duration = this.getFieldValue(result.activeTimer, 'Duration__c');
                    this.existingDuration = duration ? duration : 0;
                    this.startClock();
                }
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Init Error:', error);
                this.isLoading = false;
            });
    }

    get startDisabled() {
        return !this.selectedProject || !this.selectedActivity;
    }
    
    get inputsDisabled() {
        return this.isPendingSave;
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

    handleDescriptionChange(event) {
        this.description = event.target.value;
    }

    handleDescriptionBlur() {
        if (this.activeLineItemId) {
            updateTimerDescription({ lineItemId: this.activeLineItemId, description: this.description })
                .catch(err => console.error('Failed to update description:', err));
        }
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
            this.activeProjectName = this.getRelValue(result, 'Project__r', 'Name');
            this.activeActivityName = this.getFieldValue(result, 'Activity__c');
            this.selectedProject = this.getFieldValue(result, 'Project__c');
            this.selectedActivity = this.getFieldValue(result, 'Activity__c');
            this.description = this.getFieldValue(result, 'Description__c') || '';
            this.startTime = new Date(this.getFieldValue(result, 'Start_Time__c')).getTime();
            let duration = this.getFieldValue(result, 'Duration__c');
            this.existingDuration = duration ? duration : 0;
            this.startClock();
            this.isLoading = false;
        })
        .catch(error => {
            this.showToast('Error', error.body?.message || 'Failed to start timer', 'error');
            this.isLoading = false;
        });
    }

    handlePause() {
        this.stopClock();
        this.stopTimeMs = new Date().getTime();
        this.isPendingSave = true;
    }
    
    handleContinue() {
        let now = new Date().getTime();
        let pauseDuration = now - this.stopTimeMs;
        this.totalPauseMs = (this.totalPauseMs || 0) + pauseDuration;
        
        // Shift start time forward so the clock resumes correctly
        this.startTime += pauseDuration;
        
        this.isPendingSave = false;
        this.stopTimeMs = null;
        this.startClock();
        
        // Also fire update just in case they didn't blur
        this.handleDescriptionBlur();
    }

    get saveDisabled() {
        if (!this.stopTimeMs) return false;
        let diff = Math.max(0, this.stopTimeMs - this.startTime);
        if (this.existingDuration) {
            diff += (this.existingDuration * 60 * 60 * 1000);
        }
        let hours = diff / (1000 * 60 * 60);
        return hours <= 0.1;
    }

    handleSave() {
        this.isLoading = true;
        stopTimer({ 
            lineItemId: this.activeLineItemId, 
            stopTimeMs: this.stopTimeMs,
            totalPauseMs: this.totalPauseMs || 0,
            description: this.description
        })
        .then(() => {
            this.showToast('Success', 'Time logged successfully!', 'success');
            this.resetState();
        })
        .catch(error => {
            let errorMsg = error.body?.message || 'Failed to save timer';
            try {
                let errorObj = JSON.parse(errorMsg);
                if (errorObj.isCustomError) {
                    let formattedItems = errorObj.failedItems.map(item => 
                        `${item.date} - ${item.project} - ${item.activity}: ${item.duration} hrs`
                    ).join('\n');
                    errorMsg = `${errorObj.message}\n\nPlease create the following items manually:\n${formattedItems}`;
                    
                    this.showToast('Save Failed', errorMsg, 'error', 'sticky');
                } else {
                    this.showToast('Error', errorMsg, 'error');
                }
            } catch (e) {
                this.showToast('Error', errorMsg, 'error');
            }
            this.isLoading = false;
        });
    }

    handleDiscard() {
        this.isLoading = true;
        discardTimer({ lineItemId: this.activeLineItemId })
        .then(() => {
            this.showToast('Info', 'Timer discarded', 'info');
            this.resetState();
        })
        .catch(error => {
            this.showToast('Error', error.body?.message || 'Failed to discard timer', 'error');
            this.isLoading = false;
        });
    }

    resetState() {
        this.activeLineItemId = null;
        this.selectedProject = '';
        this.selectedActivity = '';
        this.description = '';
        this.formattedTime = '00:00:00';
        this.existingDuration = 0;
        this.stopTimeMs = null;
        this.totalPauseMs = 0;
        this.isPendingSave = false;
        this.isLoading = false;
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
        let diff = Math.max(0, now - this.startTime);
        
        // Add existing duration (in hours) to the difference
        if (this.existingDuration) {
            diff += (this.existingDuration * 60 * 60 * 1000);
        }
        
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

    showToast(title, message, variant, mode = 'dismissible') {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant, mode })
        );
    }
}
