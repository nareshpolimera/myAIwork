global class TestScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        System.debug('TestScheduler ran at: ' + System.now());
        
        // Add your actual logic here, e.g.:
        // update some record, send an email, call a method, etc.
    }
}