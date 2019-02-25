/**
 * Used to calculate and save a set of quotes in serial.
 * Implemented as BATCH APEX chain where each BATCH job reads, calculates, and saves only one quote to ensure it scales.
 * Since its in serial, the next BATCH job in the chain does not start until the async calculate is finished and the quote is saved.
 *
 * This leverages the Salesforce CPQ APIs to read, calculate, and save.
 * https://developer.salesforce.com/docs/atlas.en-us.cpq_dev_api.meta/cpq_dev_api/cpq_api_pricing_parent.htm
 *
 * Does not rely on making an update to quote record to initiate the calculate.
 */
global with sharing class CPQBatchCalculator implements Database.Batchable<Id>,Database.Stateful, SBQQ.CalculateCallback {

	/**
	 * Start the processing (calculate + save) of all quotes provided in the list of ids.
	 * Can only processes up to 7000 quotes at a time.
	 * This should be the ony API called directly.
	 *
	 * For example:
	 * CPQBatchCalculator.start(new List<Id>{'a0u54000000UoPk', 'a0u54000000UoPp'});
	 *
	 * @param quoteIds
	 */
	public static void start(Id[] quoteIds) {
		// assert the input is not null and not more than 7000 IDs
		System.assert(quoteIds != null);
		System.assert(quoteIds.size() <= 7000);

		// clean up the CPQBatchCalculator__c record from the previous run
		SObject[] ids = [SELECT Id FROM CPQBatchCalculator__c];
		if(ids.size() > 0)
			delete ids;

		// persist the list of quote ids being processed
		String idJSON = JSON.serialize(quoteIds);
		SObject current = new CPQBatchCalculator__c(QuoteIds__c=idJSON);
		insert current;

		// start the batch calculator
		Database.executeBatch(new CPQBatchCalculator());
	}

	// properties used when this class is serialized as an input to the QuoteCalculator API
	private Map<String,Object> quote;
	private String callbackClass = 'CPQBatchCalculator';

	/**
	*  Reads the quote id list persisted in CPQBatchCalculator__c,
	*  returns the first one, and deletes the one retuned from the persisted list
	*/
	public Iterable<Id> start(Database.BatchableContext BC) {
		return readAndDeleteCurrentQuoteId();
	}

	/**
	 * Executes the calculation of a single quote by first reading it and calculating it
	 * @param BC
	 * @param ids a list of one quote id
	 */
	public void execute(Database.BatchableContext BC, Id[] ids){
		try {
			// read the quote
			String quote = SBQQ.ServiceRouter.read('SBQQ.QuoteAPI.QuoteReader', ids.get(0));
			// deserialize the quote string response to a Map and assign as a property to this class
			this.quote = (Map<String,Object>) JSON.deserializeUntyped(quote);
			// calculate the quote with this class as an input to send through the quote and callback class
			SBQQ.ServiceRouter.load('SBQQ.QuoteAPI.QuoteCalculator', null, JSON.serialize(this));
		} catch (Exception e) {
			// if any execute within this batch fails,
			// then abort the entire batch as most likely all subsequent executes will also fail
			System.abortJob(BC.getJobId());
			throw e;
		}
	}

	/**
	 * Satisfies SBQQ.CalculateCallback contract and delegated to after the async calculate finishes.
	 * Saves the quote and initiates the processing of the next quote
	 *
	 * @param quote
	 */
	global void callback(String quote) {
		// save the quote
		SBQQ.ServiceRouter.save('SBQQ.QuoteAPI.QuoteSaver', quote);

		// queue up the next quote calculate and save
		Database.executeBatch(new CPQBatchCalculator());
	}

	private List<Id> readAndDeleteCurrentQuoteId() {
		// read the batch calculator reciord to get the next quote Id
		CPQBatchCalculator__c current = [SELECT Id, QuoteIds__c FROM CPQBatchCalculator__c][0];
		List<Id> quoteIds = (List<Id>) JSON.deserialize(current.QuoteIds__c, List<Id>.class);

		// the response should just be a list of the one quote id, the first one
		List<Id> response = new List<Id>();

		// if our quote id list is not empty then add the first id to the response and remove it from the persisted list
		if(quoteIds.size() > 0) {
			response.add(quoteIds.remove(0));
			current.QuoteIds__c = JSON.serialize(quoteIds);
			update current;
		}

		return response;
	}

	public void finish(Database.BatchableContext BC) {}
}