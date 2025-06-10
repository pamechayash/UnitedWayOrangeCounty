import { LightningElement, wire,api } from 'lwc';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
const FIELDS = ['Integration__c.DxF_to_GetHelp_Put__c','Integration__c.Status__c'];
export default class JsonEditModal extends LightningElement {
    @api recordId;
    isModalOpen = true;
    jsonContent = '';
    integrationResponse;

    @api invoke(){
        this.isModalOpen = this.integrationResponse.fields.Status__c.value=='Error';
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    recordHandler({ data, error }) {
        if (data) {
            this.integrationResponse=data;

            this.jsonContent = this.jsonToHtml(JSON.stringify(JSON.parse(data.fields.DxF_to_GetHelp_Put__c.value,null, 2)));
            
            // this.isModalOpen = data.fields.Status__c.value=='Error';
            console.log(this.jsonContent);
        } else if (error) {
            this.showToast('Error loading JSON', error.body?.message || error.message, 'error');
        }
    }
     jsonToHtml(json) {
        if (typeof json === 'string') {
            try {
                json = JSON.parse(json);
            } catch (e) {
                return `<pre style="color: red;">Invalid JSON</pre>`;
            }
        }
    
        const formatted = JSON.stringify(json, null, 2);
    
        return `<pre style="background:#f4f4f4; padding:12px; border-radius:4px; font-family:monospace;">${
            formatted
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/("(\\u[\da-fA-F]{4}|\\[^u]|[^\\"])*"(?=\s*:))/g, '<span style="color:brown;">$1</span>') // keys
                .replace(/(:\s*)("(\\u[\da-fA-F]{4}|\\[^u]|[^\\"])*")/g, '$1<span style="color:green;">$2</span>') // strings
                .replace(/(:\s*)(\b\d+(\.\d+)?\b)/g, '$1<span style="color:blue;">$2</span>') // numbers
                .replace(/(:\s*)(true|false|null)/g, '$1<span style="color:purple;">$2</span>') // booleans/null
        }</pre>`;
    }

    htmlToJson(html) {
      
    // Step 1: Strip all HTML tags (e.g., <span>...</span>)
    let plainText = html.replace(/<\/?[^>]+(>|$)/g, '');

    // Step 2: Decode HTML entities
    plainText = plainText
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&amp;/g, '&')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'");

    // Step 3: Validate and return stringified JSON
    try {
        const obj = JSON.parse(plainText);
        return JSON.stringify(obj); // compact valid JSON string
    } catch (e) {
        throw new Error('Invalid JSON content'); 
    }
    }
    handleCloseModal() {
        this.isModalOpen = false;
    }

    handleJsonChange(event) {
        this.jsonContent = event.target.value;
    }

    handleSave() {
       this.jsonContent = this.htmlToJson(this.jsonContent);
       console.log('json'+ this.jsonContent);
        const fields = {
            Id: this.recordId,
            DxF_to_GetHelp_Put__c:  this.jsonContent
        };
        updateRecord({ fields })
        .then(() => {
            this.showToast('Success', 'JSON updated successfully.', 'success');
            this.isModalOpen = false;
        })
        .catch(error => {
            this.showToast('Error', error.body?.message || error.message, 'error');
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}