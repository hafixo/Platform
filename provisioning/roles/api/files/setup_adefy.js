use admin;
db.auth("admin", "6U22iEbEorpL6sBytss5hsSOLr8ud3rlAg2PyyplW7oJGTkK");

use adefy;
if(db.system.users.find().count() == 0) {
  db.addUser("adefy", "CdZcBjub3NRpoQNPhlrFQ6sZMgXI93DZGUE1CwkIgl8FjWCn");
}

use adefy_development;
if(db.system.users.find().count() == 0) {
  db.addUser("adefy", "JPJsehsZkrBe15xIcQH419C2ZRoc4hg4uA90KVgjFkDbnKpQ");
}

use adefy_testing;
if(db.system.users.find().count() == 0) {
  db.addUser("adefy", "l3xzkDSBhGsAGhGpDWTqOX7NrQWyeNI3CXEfIiyMA2ckKbOn");
}
