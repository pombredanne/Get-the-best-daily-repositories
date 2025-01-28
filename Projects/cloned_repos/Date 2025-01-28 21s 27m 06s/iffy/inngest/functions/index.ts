import recordsFns from "./records";
import moderationsFns from "./moderations";
import userActionsFns from "./user-actions";
import appealActionsFns from "./appeal-actions";
import analyticsFns from "./analytics";

export default [...recordsFns, ...moderationsFns, ...userActionsFns, ...appealActionsFns, ...analyticsFns];
