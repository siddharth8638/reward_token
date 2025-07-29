// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title RewardToken
 * @dev ERC20 token for rewarding students
 */
contract RewardToken is ERC20, Ownable {
    uint8 private _decimals;
    
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _decimals = decimals_;
        _mint(msg.sender, initialSupply * 10**decimals_);
    }
    
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    /**
     * @dev Mint tokens to a specific address (only owner)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev Burn tokens from caller's balance
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}

/**
 * @title AssignmentSystem
 * @dev Main contract for managing assignments, submissions, and rewards
 */
contract AssignmentSystem is Ownable, ReentrancyGuard, Pausable {
    
    // Structs
    struct Assignment {
        uint256 id;
        string title;
        string description;
        string contentHash; // IPFS hash of assignment content
        address instructor;
        uint256 deadline;
        uint256 rewardAmount;
        uint256 maxSubmissions;
        uint256 submissionCount;
        bool isActive;
        AssignmentType assignmentType;
    }
    
    struct Submission {
        uint256 assignmentId;
        address student;
        string submissionHash; // IPFS hash of student's submission
        uint256 submittedAt;
        bool isGraded;
        uint256 grade; // Grade out of 100
        bool rewardClaimed;
        string feedback; // IPFS hash of feedback
    }
    
    enum AssignmentType {
        Essay,
        Code,
        MultipleChoice,
        Project,
        Other
    }
    
    // State variables
    RewardToken public rewardToken;
    uint256 public nextAssignmentId = 1;
    uint256 public minimumPassingGrade = 70; // 70%
    
    // Mappings
    mapping(uint256 => Assignment) public assignments;
    mapping(uint256 => mapping(address => Submission)) public submissions; // assignmentId => student => submission
    mapping(address => bool) public authorizedOracles; // Trusted graders
    mapping(address => bool) public authorizedInstructors;
    mapping(address => uint256[]) public studentAssignments; // student => assignment IDs
    mapping(address => uint256) public studentRewardBalance;
    
    // Events
    event AssignmentCreated(
        uint256 indexed assignmentId,
        address indexed instructor,
        string title,
        uint256 deadline,
        uint256 rewardAmount
    );
    
    event SubmissionMade(
        uint256 indexed assignmentId,
        address indexed student,
        string submissionHash,
        uint256 submittedAt
    );
    
    event SubmissionGraded(
        uint256 indexed assignmentId,
        address indexed student,
        uint256 grade,
        bool passed
    );
    
    event RewardClaimed(
        uint256 indexed assignmentId,
        address indexed student,
        uint256 rewardAmount
    );
    
    event OracleAuthorized(address indexed oracle);
    event OracleRevoked(address indexed oracle);
    event InstructorAuthorized(address indexed instructor);
    event InstructorRevoked(address indexed instructor);
    
    // Modifiers
    modifier onlyOracle() {
        require(authorizedOracles[msg.sender], "Not authorized oracle");
        _;
    }
    
    modifier onlyInstructor() {
        require(authorizedInstructors[msg.sender], "Not authorized instructor");
        _;
    }
    
    modifier validAssignment(uint256 assignmentId) {
        require(assignmentId > 0 && assignmentId < nextAssignmentId, "Invalid assignment ID");
        require(assignments[assignmentId].isActive, "Assignment not active");
        _;
    }
    
    constructor(address _rewardToken) Ownable(msg.sender) Pausable() {
        rewardToken = RewardToken(_rewardToken);
        authorizedOracles[msg.sender] = true;
        authorizedInstructors[msg.sender] = true;
    }
    
    /**
     * @dev Create a new assignment
     */
    function createAssignment(
        string memory _title,
        string memory _description,
        string memory _contentHash,
        uint256 _deadline,
        uint256 _rewardAmount,
        uint256 _maxSubmissions,
        AssignmentType _assignmentType
    ) external onlyInstructor whenNotPaused {
        require(_deadline > block.timestamp, "Deadline must be in future");
        require(_maxSubmissions > 0, "Max submissions must be > 0");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_contentHash).length > 0, "Content hash cannot be empty");
        
        uint256 assignmentId = nextAssignmentId++;
        
        assignments[assignmentId] = Assignment({
            id: assignmentId,
            title: _title,
            description: _description,
            contentHash: _contentHash,
            instructor: msg.sender,
            deadline: _deadline,
            rewardAmount: _rewardAmount,
            maxSubmissions: _maxSubmissions,
            submissionCount: 0,
            isActive: true,
            assignmentType: _assignmentType
        });
        
        emit AssignmentCreated(assignmentId, msg.sender, _title, _deadline, _rewardAmount);
    }
    
    /**
     * @dev Submit assignment by student
     */
    function submitAssignment(
        uint256 _assignmentId,
        string memory _submissionHash
    ) external validAssignment(_assignmentId) whenNotPaused {
        Assignment storage assignment = assignments[_assignmentId];
        
        require(block.timestamp <= assignment.deadline, "Submission deadline passed");
        require(assignment.submissionCount < assignment.maxSubmissions, "Max submissions reached");
        require(bytes(_submissionHash).length > 0, "Submission hash cannot be empty");
        require(submissions[_assignmentId][msg.sender].submittedAt == 0, "Already submitted");
        
        submissions[_assignmentId][msg.sender] = Submission({
            assignmentId: _assignmentId,
            student: msg.sender,
            submissionHash: _submissionHash,
            submittedAt: block.timestamp,
            isGraded: false,
            grade: 0,
            rewardClaimed: false,
            feedback: ""
        });
        
        assignment.submissionCount++;
        studentAssignments[msg.sender].push(_assignmentId);
        
        emit SubmissionMade(_assignmentId, msg.sender, _submissionHash, block.timestamp);
    }
    
    /**
     * @dev Grade submission (oracle/instructor only)
     */
    function gradeSubmission(
        uint256 _assignmentId,
        address _student,
        uint256 _grade,
        string memory _feedback
    ) external onlyOracle validAssignment(_assignmentId) {
        require(_grade <= 100, "Grade must be <= 100");
        
        Submission storage submission = submissions[_assignmentId][_student];
        require(submission.submittedAt > 0, "No submission found");
        require(!submission.isGraded, "Already graded");
        
        submission.isGraded = true;
        submission.grade = _grade;
        submission.feedback = _feedback;
        
        bool passed = _grade >= minimumPassingGrade;
        
        // If passed, make reward available for claiming
        if (passed) {
            studentRewardBalance[_student] += assignments[_assignmentId].rewardAmount;
        }
        
        emit SubmissionGraded(_assignmentId, _student, _grade, passed);
    }
    
    /**
     * @dev Claim reward for passing grade
     */
    function claimReward(uint256 _assignmentId) external nonReentrant whenNotPaused {
        Submission storage submission = submissions[_assignmentId][msg.sender];
        
        require(submission.isGraded, "Submission not graded yet");
        require(submission.grade >= minimumPassingGrade, "Grade below passing threshold");
        require(!submission.rewardClaimed, "Reward already claimed");
        
        uint256 rewardAmount = assignments[_assignmentId].rewardAmount;
        require(studentRewardBalance[msg.sender] >= rewardAmount, "Insufficient reward balance");
        
        submission.rewardClaimed = true;
        studentRewardBalance[msg.sender] -= rewardAmount;
        
        // Transfer reward tokens to student
        require(rewardToken.transfer(msg.sender, rewardAmount), "Token transfer failed");
        
        emit RewardClaimed(_assignmentId, msg.sender, rewardAmount);
    }
    
    /**
     * @dev Batch claim multiple rewards
     */
    function claimMultipleRewards(uint256[] memory _assignmentIds) external nonReentrant whenNotPaused {
        uint256 totalReward = 0;
        
        for (uint256 i = 0; i < _assignmentIds.length; i++) {
            uint256 assignmentId = _assignmentIds[i];
            Submission storage submission = submissions[assignmentId][msg.sender];
            
            if (submission.isGraded && 
                submission.grade >= minimumPassingGrade && 
                !submission.rewardClaimed) {
                
                uint256 rewardAmount = assignments[assignmentId].rewardAmount;
                submission.rewardClaimed = true;
                totalReward += rewardAmount;
                
                emit RewardClaimed(assignmentId, msg.sender, rewardAmount);
            }
        }
        
        require(totalReward > 0, "No rewards to claim");
        require(studentRewardBalance[msg.sender] >= totalReward, "Insufficient reward balance");
        
        studentRewardBalance[msg.sender] -= totalReward;
        require(rewardToken.transfer(msg.sender, totalReward), "Token transfer failed");
    }
    
    // Admin functions
    function authorizeOracle(address _oracle) external onlyOwner {
        authorizedOracles[_oracle] = true;
        emit OracleAuthorized(_oracle);
    }
    
    function revokeOracle(address _oracle) external onlyOwner {
        authorizedOracles[_oracle] = false;
        emit OracleRevoked(_oracle);
    }
    
    function authorizeInstructor(address _instructor) external onlyOwner {
        authorizedInstructors[_instructor] = true;
        emit InstructorAuthorized(_instructor);
    }
    
    function revokeInstructor(address _instructor) external onlyOwner {
        authorizedInstructors[_instructor] = false;
        emit InstructorRevoked(_instructor);
    }
    
    function updateMinimumPassingGrade(uint256 _grade) external onlyOwner {
        require(_grade <= 100, "Grade must be <= 100");
        minimumPassingGrade = _grade;
    }
    
    function deactivateAssignment(uint256 _assignmentId) external onlyOwner {
        assignments[_assignmentId].isActive = false;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // View functions
    function getAssignment(uint256 _assignmentId) external view returns (Assignment memory) {
        return assignments[_assignmentId];
    }
    
    function getSubmission(uint256 _assignmentId, address _student) external view returns (Submission memory) {
        return submissions[_assignmentId][_student];
    }
    
    function getStudentAssignments(address _student) external view returns (uint256[] memory) {
        return studentAssignments[_student];
    }
    
    function isSubmissionEligibleForReward(uint256 _assignmentId, address _student) external view returns (bool) {
        Submission memory submission = submissions[_assignmentId][_student];
        return submission.isGraded && 
               submission.grade >= minimumPassingGrade && 
               !submission.rewardClaimed;
    }
    
    /**
     * @dev Get assignment statistics
     */
    function getAssignmentStats(uint256 _assignmentId) external view returns (
        uint256 totalSubmissions,
        uint256 gradedSubmissions,
        uint256 passedSubmissions,
        uint256 avgGrade
    ) {
        // Note: This is a simplified version. In production, you'd want to track these stats
        // more efficiently rather than iterating (which could be gas-expensive)
        return (assignments[_assignmentId].submissionCount, 0, 0, 0);
    }
    
    // Emergency functions
    function emergencyWithdrawTokens(uint256 _amount) external onlyOwner {
        require(rewardToken.transfer(owner(), _amount), "Token transfer failed");
    }
    
    function emergencyDepositTokens(uint256 _amount) external onlyOwner {
        require(rewardToken.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
    }
}
