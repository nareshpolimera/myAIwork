public with sharing class CaseFeedService {
    @AuraEnabled(cacheable=true)
    public static String getCaseFeedData(Id caseId) {
        if (caseId == null) {
            return null;
        }

        System.debug('Hey');

        List<FeedItem> feedItems = [
            SELECT Id, Type, Body, CreatedBy.Name, CreatedDate,
                (
                    SELECT Id, CommentBody, CreatedBy.Name, CreatedDate
                    FROM FeedComments
                    ORDER BY CreatedDate ASC
                )
            FROM FeedItem
            WHERE ParentId = :caseId
                AND Type IN ('TextPost', 'ContentPost', 'LinkPost', 'TrackedChange')
            WITH USER_MODE
            ORDER BY CreatedDate ASC
            LIMIT 25
        ];

        List<Map<String, Object>> feedData = new List<Map<String, Object>>();
        for (FeedItem item : feedItems) {
            List<Map<String, Object>> comments = new List<Map<String, Object>>();
            for (FeedComment comment : item.FeedComments) {
                comments.add(new Map<String, Object>{
                    'id' => comment.Id,
                    'commentBody' => comment.CommentBody,
                    'createdBy' => comment.CreatedBy.Name,
                    'createdDate' => comment.CreatedDate
                });
            }
            feedData.add(new Map<String, Object>{
                'id' => item.Id,
                'type' => String.valueOf(item.Type),
                'body' => item.Body,
                'createdBy' => item.CreatedBy.Name,
                'createdDate' => item.CreatedDate,
                'comments' => comments
            });
        }

        if (feedData.isEmpty()) {
            return null;
        }
        return JSON.serializePretty(feedData);
    }

    @AuraEnabled
    public static String getCaseSummaryFromPromptTemplate(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case Id is required.');
        }
        try {
            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput =
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();

            ConnectApi.WrappedValue caseValue = new ConnectApi.WrappedValue();
            caseValue.value = new Map<String, String>{ 'id' => caseId };

            promptInput.inputParams = new Map<String, ConnectApi.WrappedValue>{
                'Input:Case' => caseValue
            };
            promptInput.isPreview = false;
            promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            promptInput.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    'PT_Case_Summary_from_Feed_Comments',
                    promptInput
                );

            if (generationsOutput.generations != null && !generationsOutput.generations.isEmpty()) {
                return generationsOutput.generations[0].text;
            }
            return null;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to generate case summary: ' + e.getMessage());
        }
    }
}