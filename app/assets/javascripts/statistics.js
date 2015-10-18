var request_graph = function(id){
	var resource = '/statistics/' + id + '/generate_analytics'
    var data = {
    	user : $("#users")[0].value
    }
 	$.get(resource, data, function(){
 		console.log("Sent username to statistics controller.")
 	});
}