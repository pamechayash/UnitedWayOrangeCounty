public without sharing class PublicSearchQueueHandler implements Queueable {
    
    public String queueId;

    public PublicSearchQueueHandler(String queueId){
        this.queueId = queueId;
    }

    public void execute(QueueableContext context) {
        Group queue = [SELECT Id, Name
                        FROM Group
                        WHERE Id = :this.queueId];
        queue.Name += ' - DEPRECATED';
        update queue;

        Integer queueCounter = [SELECT count()
                                FROM Group
                                WHERE Type = 'Queue' AND Name LIKE '%Anonymous Search Owners%'];

        Group newQueue = new Group(
            Name = (queueCounter + 1) + '. Anonymous Search Owners', 
            Type = 'Queue'
        );
        insert newQueue;

        QueuesObject testQueue = new QueueSObject(
            QueueID = newQueue.id, 
            SObjectType = 'Case'
        );
        insert testQueue;
    }
}