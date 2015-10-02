var host = document.domain  // yank hostname
var port = 3000  // port of development server
var data = { // data to be passed
	// users : document.getElementById('users').value
    start_hour : document.getElementById("start_time_hour"),
    // start_hour : document.getElementById("start_time_minute"),
    // end_hour : document.getElementById("end_time_hour"),
    // end_minute : document.getElementById("end_time_minute")
};
// connect to server, no need for protocol prefix
var connection = new WebSocketRails("localhost:3000/websocket");
var success = function(data) { console.log("Successfully")}
// upon opening a conection
connection.on_open = function() {
	console.log("Connection has been established.");
	connection.bind('events.success', data, success);
}
// bind websocket connection to button press
connection.bind('events.success', data, success);
function request_new_graph(bash_user){
    // function which is triggered by a button press
 	connection.trigger('events.generate_graph', {users: bash_user});
}






