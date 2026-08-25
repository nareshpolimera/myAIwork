@IsTest
private class CodeReviewServiceTest {
    @IsTest
    static void normalizeFindingsTrimsAndRemovesBlankValues() {
        List<String> findings = new List<String>{
            '  Missing assertion  ',
            null,
            '',
            'Bulkification issue'
        };

        List<String> result = CodeReviewService.normalizeFindings(findings);

        Assert.areEqual(2, result.size());
        Assert.areEqual('Missing assertion', result[0]);
        Assert.areEqual('Bulkification issue', result[1]);
    }

    @IsTest
    static void normalizeFindingsHandlesNullInput() {
        List<String> result = CodeReviewService.normalizeFindings(null);

        Assert.isNotNull(result);
        Assert.areEqual(0, result.size());
    }

    @IsTest
    static void normalizeFindingsHandlesBulkInput() {
        List<String> findings = new List<String>();
        for (Integer index = 0; index < 200; index++) {
            findings.add(' Finding ' + index + ' ');
        }

        List<String> result = CodeReviewService.normalizeFindings(findings);

        Assert.areEqual(200, result.size());
        Assert.areEqual('Finding 0', result[0]);
        Assert.areEqual('Finding 199', result[199]);
    }
}
