import { LightningElement, api } from "lwc";

export default class KpiCard extends LightningElement {
  @api cardId;
  @api title;
  @api value;
  @api trend;

  get iconName() {
    if (this.trend === "up") return "utility:arrowup";
    if (this.trend === "down") return "utility:arrowdown";
    return "utility:dash";
  }

  get iconClass() {
    if (this.trend === "up")
      return "slds-icon-utility-arrowup slds-m-left_x-small success-icon";
    if (this.trend === "down")
      return "slds-icon-utility-arrowdown slds-m-left_x-small error-icon";
    return "slds-m-left_x-small flat-icon";
  }

  handleCardClick() {
    const selectEvent = new CustomEvent("cardselect", {
      detail: { cardId: this.cardId, title: this.title }
    });
    this.dispatchEvent(selectEvent);
  }
}