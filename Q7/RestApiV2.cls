@RestResource(urlMapping='/v2/Opportunities/*')
global with sharing class RestApiV2 {
    private static V2Engine engine = new V2Engine();
    @HttpGet
    global static RestApi.OpportunityWrapper doGet() {
        return engine.handleGet(RestContext.request);
    }
    private class V2Engine extends RestApi.BaseRestApi {
    
        public override RestApi.OpportunityWrapper handleGet(RestRequest req) {
            RestApi.OpportunityWrapper wrapper = super.handleGet(req);
            if(wrapper != null && wrapper.opp != null && wrapper.opp.Amount > 0) {
                Decimal totalCost = 0;
                
                if(wrapper.oppLineItems != null) {
                    for(OpportunityLineItem oli : wrapper.oppLineItems) {
                        Decimal cost = (oli.Quantity != null ? oli.Quantity : 0) * (oli.UnitPrice != null ? oli.UnitPrice : 0);
                        System.debug('Calculated cost for line item ' + oli.Id + ': ' + cost);
                        totalCost += cost;
                    }
                    System.debug('Total cost calculated from line items: ' + totalCost);
                }
                Decimal marginPercent = ((wrapper.opp.Amount - totalCost) / wrapper.opp.Amount) * 100;
                System.debug('Calculated margin percent before formatting: ' + wrapper.opp);
                System.debug('Calculated margin percent: ' + marginPercent);
                System.debug('Original opportunity amount: ' + wrapper.opp.Amount);
                wrapper.GrossMargin = String.valueOf(marginPercent.setScale(2)) + '%';
                System.debug('Calculated gross margin: ' + wrapper.GrossMargin);
            }
            
            return wrapper;
        }
    }
}