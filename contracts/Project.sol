// SPDX-License-Identifier: MIT

pragma solidity >=0.4.16 < 0.9.0;
pragma abicoder v2;

// Importing OpenZeppelin's SafeMath Implementation
// No longer needed after solidity 0.8.0
// import "./libraries/SafeMath.sol";

contract Project {
    // using SafeMath for uint256;
    
    event Contributed(address _from, uint _value);
    event CreatedRequest(uint requestID);
    event ApprovedReq(address _from, uint _requestID, uint _totalApprovals);
    event DeniedReq(address _from, uint _requestID, uint _totalDenials);
    event CancelledReq(uint _requestID, string _reason);
    event FinalizedReq(uint _requestID);
    event ProjectCancelled(string _reason);
    event ProjectFinished(uint _value, string _msg);
    
    struct Request {
        uint id;
        string title;
        string desc;
        string milestoneId;
        uint256 value;
        address payable vendorAddress;
        bool isComplete;
        uint approvalsCount;
        uint denialsCount;
        string imgUrl;
        string filesUrl;
        bool cancelled;
        mapping (address => uint) votes;    // 1 for positive vote, 2 for negative vote
    }
    
    struct BasicDetails {
        address owner;
        string title;
        string description;
        string imageUrl;
        string folderUrl;
        uint256 minContribution;
        bool isMap;
        string postalAddress;
        string lat;
        string lng;
        string placeName;
    }
    
    BasicDetails basic;
    
    struct RequestDetails {
        uint id;
        string title;
        string desc;
        string milestoneId;
        uint256 value;
        address payable vendorAddress;
        bool isComplete;
        uint approvalsCount;
        uint denialsCount;
        string imgUrl;
        string filesUrl;
        bool cancelled;
    }
    
    
    // creator is the Project Creator
    address public creator;
    uint256 public currentBalance = 0;
    uint256 public totalPoolBalance = 0;
    uint256 fees = 0;
    uint public approversCount = 0;
    uint public contributorsCount = 0;
    bool public cancelled = false;
    bool public finished = false;
    
    // only signed in accounts
    mapping(address => bool) public approvers;
    uint public numRequests;
    mapping(uint => Request) public requests;
    
    // Location and Place details
    
    address public devs = 0x087F5052fBcD7C02DD45fb9907C57F1EccC2bE25;
    address payable devAddress = payable(devs);
    
    // all contributors
    mapping (address => bool) public contributors;
    
    // total contributions of all contributors
    mapping (address => uint256) public contributions;
    
    modifier onlyCreator() {
        require(msg.sender == creator, "Only Creator can call this function");
        _;
    }
    
    modifier onlyDevs() {
        require(msg.sender == devs, "Only developers of this project can call this function");
        _;
    }
    
    constructor (
        string memory _projectTitle, 
        string memory _projectDesc, 
        uint256 _minContributionAmount, 
        string memory _imgUrl, 
        string memory _folderUrl,
        bool _isMap,
        string memory _postalAddress,
        string memory _latitude,
        string memory _longitude,
        string memory _placeName,
        address _creator
    ) {
        creator = _creator;
        basic.owner = creator;
        basic.title = _projectTitle;
        basic.description = _projectDesc;
        basic.imageUrl = _imgUrl;
        basic.folderUrl = _folderUrl;
        basic.minContribution = _minContributionAmount;
        basic.isMap = _isMap;
        basic.postalAddress = _postalAddress;
        basic.lat = _latitude;
        basic.lng = _longitude;
        basic.placeName = _placeName;
    }

    function getLiveDetails() public view returns(
        uint ,
        uint ,
        uint ,uint,
        bool,bool
    ) {
        uint _currentBalance = currentBalance;
        uint _totalPoolBalance = totalPoolBalance;
        uint _approversCount = approversCount;
        uint _contributorsCount = contributorsCount;
        bool _cancelled = cancelled;
        bool _finished = finished;
        
        return (
            _currentBalance,
            _totalPoolBalance,
            _approversCount,
            _contributorsCount,
            _cancelled,
            _finished
            );
    }
            
    function getBasicDetails () public view returns (BasicDetails memory) {
        return basic;
    }
    
    function getRequestByIndex(uint _requestID) public view returns (RequestDetails memory) {
        Request storage req = requests[_requestID];
        
        RequestDetails memory reqDetail;
        
        reqDetail.id = req.id;
        reqDetail.title = req.title;
        reqDetail.desc = req.desc;
        reqDetail.milestoneId = req.milestoneId;
        reqDetail.value = req.value;
        reqDetail.vendorAddress = req.vendorAddress;
        reqDetail.isComplete = req.isComplete;
        reqDetail.approvalsCount = req.approvalsCount;
        reqDetail.denialsCount = req.denialsCount;
        reqDetail.imgUrl = req.imgUrl;
        reqDetail.filesUrl = req.filesUrl;
        reqDetail.cancelled = req.cancelled;
        
        return reqDetail;
    }
    
    function isVoted(address _user, uint _requestID) public view returns (bool) {
        require(approvers[_user], "You must be a approver to vote");
        Request storage req = requests[_requestID];
        
        if(req.votes[_user] == 0) {
            return false;
        }
        
        return true;
    }
    
    function getVoteCounts(uint _requestID) public view returns (uint, uint, uint) {
        Request storage req = requests[_requestID];
        
        return (req.approvalsCount, req.denialsCount, approversCount);
    }

    // To create requests
    function createRequests(
        string memory _reqTitle,
        string memory _reqDesc, 
        uint256 _value, 
        string memory _milestoneId, 
        address payable _recipient, 
        string memory _imgUrl,
        string memory _filesUrl
    ) public onlyCreator returns (uint requestID) {
        requestID = numRequests++;
        Request storage req = requests[requestID];
        req.id = requestID;
        req.title = _reqTitle;
        req.desc = _reqDesc;
        req.value = _value;
        req.vendorAddress = _recipient;
        req.milestoneId = _milestoneId;
        req.imgUrl = _imgUrl;
        req.filesUrl = _filesUrl;
        req.isComplete = false;
        req.approvalsCount = 0;
        req.denialsCount = 0;
        req.cancelled = false;
        
        emit CreatedRequest(requestID);
    }
    
    // calc 0.05% fee
    function percentage(uint256 value, uint256 reqParts, uint256 totalParts) internal pure returns (uint256) {
        uint256 total = value;
        total *= (reqParts);
        total /= (totalParts);
        return total;
    }
    
    // Sets the developers account address, and only be called by the developers
    function setDevsNewAddress(address _devs) external onlyDevs returns (address) {
        devs = _devs;
        return devs;
    }
    
    // Cancels the request, and can only be called by the creator of the project
    function cancelRequest(uint _requestID, string memory _reason) external onlyCreator {
        require(!requests[_requestID].cancelled, "Request already cancelled by the creator of this Project");
        Request storage req = requests[_requestID];
        req.cancelled = true;
        
        emit CancelledReq(_requestID, _reason);
    }
    
    // Cancels the project, and can only be called by the creator of the project
    function cancelProject(string memory _reason) external onlyCreator {
        require(!cancelled, "Project already cancelled by the Creator");
        require(!finished, "Project already finished successfully");
        cancelled = true;
        
        emit ProjectCancelled(_reason);
    }
    
    // After the project is finished this function is called, and can only be called by the creator of the project
    function finishProject() external onlyCreator {
        require(!cancelled, "Project already cancelled by the Creator");
        require(!finished, "Project already finished successfully");
        finished = true;
        
        emit ProjectFinished(totalPoolBalance - currentBalance, "Project Finished Successfully");
    }
    
    // Check how much fees is accumulated till now, can only be called by the devs
    function checkFees() external view onlyDevs returns (uint256) {
        return fees;
    }
    
    // Transfers the fee amount to developers address
    function transferFees() external onlyDevs {
        require(fees > 0, "There is no fees available");
        uint256 feeAmount = fees;
        fees = 0;
        devAddress.transfer(feeAmount);
    }
    
    // Contribute function
    function contribute(bool _isSignedIn) public payable {
        uint256 fee = percentage(msg.value, 5, 10000);
        uint256 amount = msg.value;
        amount -= fee;
        currentBalance += (amount);
        totalPoolBalance += (amount);
        fees += (fee);
        
        if(msg.value >= basic.minContribution) {
            if(_isSignedIn == true) {
                approvers[msg.sender] = true;
                approversCount++;
            }
            contributions[msg.sender] += (amount);
            contributorsCount++;
            contributors[msg.sender] = true;
        }
        
        emit Contributed(msg.sender, msg.value);
    }
    
    // Approvers can call this function to approve a particular request
    function approveRequest (uint requestID) public {
        Request storage req = requests[requestID];
        
        require(approvers[msg.sender], "You need to be an approver to approve a request");
        require(!req.cancelled, "Request already cancelled by the creator of this Project");
        require(!req.isComplete, "Request already completed and vendor is paid");
        require(!(isVoted(msg.sender, requestID)), "You can vote only once");
        
        req.approvalsCount++;
        req.votes[msg.sender] = 1;
        
        emit ApprovedReq(msg.sender, requestID, req.approvalsCount);
    }
    
    // Deniers can call this function to approve a particular request
    function denyRequest (uint requestID) public {
        Request storage req = requests[requestID];
        
        require(approvers[msg.sender], "You need to be an approver to approve a request");
        require(!req.cancelled, "Request already cancelled by the creator of this Project");
        require(!req.isComplete, "Request already completed and vendor is paid");
        require(!(isVoted(msg.sender, requestID)), "You can vote only once");
        
        req.denialsCount++;
        req.votes[msg.sender] = 2;
        
        emit DeniedReq(msg.sender, requestID, req.denialsCount);
    }
    
    // After voting, creator will call this function to send the money to the vendor
    bool locked = false;    // just to prevent re-entrant call from a contract
    function finalizeRequest (uint _requestID) public onlyCreator {
        Request storage req = requests[_requestID];
        
        require(!req.cancelled, "Request already cancelled by the creator of this Project");
        require(!req.isComplete, "Vendor is paid already for this request");
        require(currentBalance >= req.value, "Balance in pool must be more than the requested amount");
        require(req.approvalsCount > approversCount/2, "Requires approvals from at least more than half of total contributors");
        
        require(!locked, "Re-entrant call detected!");
        locked = true;
        
        uint256 fee = percentage(req.value, 5, 10000);
        
        uint256 amount = req.value;
        amount -= (fee);
        currentBalance -= (req.value);
        req.value = 0;
        fees += (fee);
        req.isComplete = true;
        
        req.vendorAddress.transfer(amount);
        
        locked = false;
        
        emit FinalizedReq(_requestID);
    }
    
    // To check amount of refund
    function checkRefund() external view returns (uint256 refund) {
        require(contributors[msg.sender], "You must had contributed to the project to get refund");
        require(finished == true || cancelled == true, "You can only take refund after the project is finished on cancelled by the creator of the project");
        
        refund = contributions[msg.sender];
        refund *= (currentBalance);
        refund /= (totalPoolBalance);
        return refund;
    }
    
    // After the project is finished or cancelled by the creator, contributors can call this function to take back refund
    function getRefund() public {
        require(contributors[msg.sender], "You must had contributed to the project to get refund");
        require(finished == true || cancelled == true, "You can only take refund after the project is finished on cancelled by the creator of the project");
        require(contributions[msg.sender] > 0);
        
        uint256 amount = contributions[msg.sender];
        uint256 refundAmount = (amount * currentBalance);
        refundAmount /= (totalPoolBalance);
        
        uint256 fee = percentage(refundAmount, 5, 10000);
        contributions[msg.sender] = 0;
        currentBalance -= (refundAmount);
        fees += (fee);
        refundAmount -= (fee);
        
        address payable refundAddress = payable(msg.sender);
        refundAddress.transfer(refundAmount);
    }
}