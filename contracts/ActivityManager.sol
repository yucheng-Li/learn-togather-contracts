// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// 导入IERC20接口
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
contract ActivityManager {
    uint256 public activityCount;

    struct Activity {
        address tokenAddress;//代币地址
        string activeName; // 活动名称
        uint256 amount;//参与金额
        uint256 startTime;//活动开始时间
        uint256 endTime;//活动结束时间
        uint256 partyCount;//参与活动人数
        bool closed;//是否结束
        address[] participants;//参与者
    }

    mapping(uint256 => Activity) public activities;
    mapping(address => mapping(uint256 => mapping(uint256 => bool))) checkIns;
    event ActivityCreated(uint256 indexed id, address indexed tokenAddress, uint256 amount, uint256 startTime,uint256 endTime,uint256 partyCount);
    event Participation(uint256 indexed id, address indexed participant, uint256 amount);
    event CheckIn(uint256 indexed id,address indexed checker,uint256 checkTime);
    event Settle(uint256 indexed id, uint256 amount,uint256 winnerCount);

    constructor() {
    }

    function createActivity(address _tokenAddress,string memory _activeName, uint256 _amount, uint256 _startTime,uint256 _endTime,uint256 _partyCount) external  {
        
        activities[activityCount] = Activity(_tokenAddress,_activeName, _amount, _startTime, _endTime, _partyCount, false,new address[](0));
        activityCount++;
        emit ActivityCreated(activityCount, _tokenAddress, _amount, _startTime,_endTime,_partyCount);
    }
    function getActivityCount() external view returns (uint256) {
        return activityCount;
    }

   
   function getActivityList() external view returns (Activity[] memory) {
        Activity[] memory activityList = new Activity[](activityCount);

        for (uint256 i = 0; i < activityCount; i++) {
            activityList[i] = activities[i];
        }
        return activityList;
    }

    function getActivityListMe() external view returns (address) {
        Activity[] memory activityList = new Activity[](activityCount);

        for (uint256 i = 0; i < activityCount; i++) {
            activityList[i] = activities[i];
        }
        return activityList[0].participants[0];
    }

function participate(uint256 _activityId) external {
    require(_activityId < activityCount, "Invalid activity ID");
    Activity storage activity = activities[_activityId];

    // 获取 ERC20 代币合约地址
    address tokenAddress = activity.tokenAddress;
    
    // 获取 ERC20 代币实例
    IERC20 token = IERC20(tokenAddress);

    // 获取用户已授权合约的代币数量
    uint256 allowance = token.allowance(msg.sender, address(this));
    
    // 确保用户已经授权合约足够的代币数量
    require(allowance >= activity.amount, "Insufficient allowance");

    // 从用户地址向合约地址转移代币
    bool transferSuccess = token.transferFrom(msg.sender, address(this), activity.amount);
    require(transferSuccess, "Token transfer failed");
    emit Participation(_activityId, msg.sender, activity.amount);
}

    function checkIn(uint256 _activityId) external {
    require(_activityId < activityCount, "Invalid activity ID");
    Activity storage activity = activities[_activityId];

    // 确保活动是处于进行中的
    require(block.timestamp >= activity.startTime && block.timestamp <= activity.endTime, "Activity not active");
    
    // 判断当前时间在早上8点到晚上12点之间
    uint256 hour = (block.timestamp / 60 / 60) % 24;
    require(hour >= 1 && hour < 24, "Check-in available between 8 AM and 12 AM");
    
    // 确保用户当天还没有打过卡
    require(!checkIns[msg.sender][_activityId][block.timestamp / (24 * 60 * 60)], "Already checked in for today");

    // 标记用户已经打卡
    checkIns[msg.sender][_activityId][block.timestamp / (24 * 60 * 60)] = true;
    //活动中记录参与者
    activity.participants.push(msg.sender);
    // 可以发送事件记录打卡情况
    emit CheckIn(_activityId, msg.sender, block.timestamp);
}

function getParticipants(uint256  _activityId) external view returns(address[] memory) {
    return activities[_activityId].participants;
}

function getCheckIn(uint256 _activityId) external view returns (uint256[] memory) {
    uint256 daysCount = (activities[_activityId].endTime - activities[_activityId].startTime) / 1 days;
    uint256[] memory checkInsCount = new uint256[](daysCount);

    for (uint256 i = 0; i < daysCount; i++) {
        uint256 day = activities[_activityId].startTime + i * 1 days;
        if (checkIns[msg.sender][_activityId][day]) {
            checkInsCount[i] = 1;
        }
    }
    return checkInsCount;
}


    function settle(uint256 _activityId) external {
    require(_activityId < activityCount, "Invalid activity ID");
    Activity storage activity = activities[_activityId];

    // 确保活动已经结束
    require(block.timestamp > activity.endTime, "Activity not ended yet");

    // 检查活动是否已经关闭（避免重复结算）
    require(!activity.closed, "Activity already settled");
    activities[_activityId].closed = true;

    // 存储按时参与的用户
    address[] memory participants = new address[](activity.partyCount);
    uint256 participantsCount = 0;

    // 遍历活动期间的每一天
    uint256 daysCount = (activity.endTime - activity.startTime) / (24 * 60 * 60);
    for (uint256 i = 0; i < daysCount; i++) {
        uint256 day = activity.startTime + i * (24 * 60 * 60);
        if (checkIns[msg.sender][_activityId][day]) {
            participants[participantsCount++] = msg.sender;
        }
    }

    // 计算每个参与者的奖励
    uint256 totalReward = activity.amount; // 假设奖励就是参与金额
    uint256 rewardPerParticipant = totalReward / participantsCount;

    // 批量发送奖励代币给按时参与的用户
    for (uint256 i = 0; i < participantsCount; i++) {
        IERC20(activity.tokenAddress).transfer(participants[i], rewardPerParticipant);
    }

    emit Settle(_activityId, totalReward, participantsCount);
}


}
