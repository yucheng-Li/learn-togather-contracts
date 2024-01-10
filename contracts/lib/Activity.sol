// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
library Activity {
    struct Info {
        address tokenAddress;//代币地址
        string activeName; // 活动名称
        uint256 amount;//参与金额
        uint256 startTime;//活动开始时间
        uint256 endTime;//活动结束时间
        uint256 partyCount;//参与活动人数
        bool closed;//是否结束
        address[] participants;//参与者
    }
}
    