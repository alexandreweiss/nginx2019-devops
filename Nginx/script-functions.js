function authorize(req, res) {
    var n = 0;
    var servicesCodes = req.variables.servicesCodes.split("|");

    var callNextService = function() {

        function done(reply) {
            if (reply.status == 200) {
                res.return(200);
                return;
            }

            callNextService();
        }

        if (n == servicesCodes.length) {
            res.return(403);
            return;
        }
        req.subrequest("/" + servicesCodes[n++] + "/authorized.html", '', done);
    }
    callNextService();
}