/**
 * @file dashboardProfile.js
 * @description LWC for displaying employee dashboard profile with configurable columns
 */

import { LightningElement, api, track, wire } from 'lwc';
import getEmployeeDetails from '@salesforce/apex/GetDashboardProfileDetails.getEmployeeDetails';
import USER_ID from '@salesforce/user/Id';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// LMS imports for handling user selection across components
import { subscribe, MessageContext } from 'lightning/messageService';
import SELECTED_USER_CHANNEL from '@salesforce/messageChannel/SelectedUserChannel__c';

export default class dashboardProfile extends LightningElement {
    // Public properties for component configuration
    @api showNullFields;     // Controls visibility of null field values
    @api column1Fields;      // Comma-separated list of fields for first column
    @api column2Fields;      // Comma-separated list of fields for second column
    @api column3Fields;      // Comma-separated list of fields for third column
    
    // Private properties for data storage
    column1Data = [];        // Processed data for first column
    column2Data = [];        // Processed data for second column
    column3Data = [];        // Processed data for third column
    employeeData;            // Raw employee data

    // Lightning Message Service configuration
    @wire(MessageContext)
    messageContext;

    subscription = null;
    selectedUserId = USER_ID; // Initialize with current user's ID

    /**
     * @description Lifecycle hook when component is inserted into the DOM
     */
    connectedCallback() {
        this.subscribeToMessageChannel();
        this.fetchEmployeeDetails();
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    /**
     * @description Subscribes to LMS channel for user selection updates
     */
    subscribeToMessageChannel() {
        if (this.subscription) {
            return;
        }
        this.subscription = subscribe(
            this.messageContext,
            SELECTED_USER_CHANNEL,
            (message) => this.handleMessage(message)
        );
    }

    /**
     * @description Handles incoming LMS messages
     * @param {Object} message - Message containing selected user ID
     */
    handleMessage(message) {
        this.selectedUserId = message.selectedUserId;
        this.fetchEmployeeDetails();
    }

    /**
     * @description Fetches employee details from the server
     */
    fetchEmployeeDetails() {
        getEmployeeDetails({ userID: this.selectedUserId })
            .then((data) => {
                this.employeeData = data;
                this.processFieldOrder();
            })
            .catch((error) => {
                this.showToast('Error', "Error fetching employee details", 'error');
                console.log('Error fetching employee details',error);
            });
    }

    /**
     * @description Processes field ordering for all columns
     */
    processFieldOrder() {
        if (this.employeeData) {
            if (this.column1Fields) {
                this.column1Data = this.processColumnFields(this.column1Fields);
            }
            if (this.column2Fields) {
                this.column2Data = this.processColumnFields(this.column2Fields);
            }
            if (this.column3Fields) {
                this.column3Data = this.processColumnFields(this.column3Fields);
            }
        }
    }

    /**
     * @description Processes fields for a single column
     * @param {String} fieldString - Comma-separated list of field names
     * @returns {Array} Processed field data with labels and values
     */
    processColumnFields(fieldString) {
        let fields = fieldString.split(',').map(field => field.trim());
        
        // Filter out null fields if showNullFields is false
        if (!this.showNullFields) {
            fields = fields.filter(field => this.employeeData[field] != null);
        }
        
        // Transform field names into label-value pairs
        return fields.map(field => ({
            label: field.replace(/([A-Z])/g, ' $1').trim(), // Add spaces before capital letters
            value: this.employeeData[field] ?? 'N/A'
        }));
    }
}

/**
 * Field configuration examples:
 * Name,PhoneNumber,Email,HireDate,LastWorkingDate
 * ClientManager,ClientManagerEmail,Projects
 * TotalBillableHours,TotalNonBillableHours,TotalAbsenceHours,TotalHours,VacationsTaken
 */