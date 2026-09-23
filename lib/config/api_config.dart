class ApiConfig {
  // ============ SET THIS TO CONTROL API MODE ============
  static const bool useRealApi = true;  // true = real backend, false = dummy data
  // ============ BASE URL ============
  // Change this when switching environments
  static const String baseUrl = 'http://192.168.100.10:8080'; // Home IP
  //static const String baseUrl = 'http://192.168.43.166:8080'; // Emaz IP
  // static const String baseUrl = 'https://pulsatory-preeffectual-ila.ngrok-free.dev'; // ngrok


  // ============ AUTHENTICATION APIS ============
  static const String login = '/api/auth/login';//done
  static const String logout = '/api/auth/logout';//done
  static const String register = '/api/register/role';//done
  static const String changePassword = '/api/password/change';//done
//  static const String getUserByEmail = '/api/auth/user'; // + ?email={email}

  // ============ NEW REGISTRATION APIS (Temp User + OTP) ============
  static const String registerTemp = '/api/register/register-temp';
  static const String verifyAndSave = '/api/register/verify-and-save';

  // ============ EMAIL VERIFICATION APIS (SIGNUP) ============
  static const String sendOtp = '/api/verify/send-otp';
  static const String verifyOtp = '/api/verify/verify-otp';
  static const String resendOtp = '/api/verify/resend-otp';
  static const String checkVerification = '/api/verify/check';

// ============ FORGOT PASSWORD APIS ============
  static const String forgotPassword = '/api/verify/forgot-password';
  static const String verifyResetOtp = '/api/verify/verify-reset-otp';
  static const String resetPassword = '/api/verify/reset-password';
  static const String resendForgotOtp = '/api/verify/resend-forgot-otp';
//  static const String extendOtp = '/api/verify/extend-otp';

  // ============ PROFILE APIS ============
  static const String tutorProfile = '/api/register/tutor/profile';
  static const String studentProfile = '/api/register/student/profile';
  static const String editTutorProfile = '/api/register/tutor/profile/edit';
  static const String editStudentProfile = '/api/register/student/profile/edit';
  static const String getTutorProfile = '/api/register/tutor/profile';
  static const String getStudentProfile = '/api/register/student/profile';
  static const String editStudentProfileJson = '/api/register/student/profile/edit-json';
  static const String editTutorProfileJson = '/api/register/tutor/profile/edit-json';
  static const String uploadTutorImage = '/api/profile-image/upload';
  static const String uploadStudentImage = '/api/student-image/upload';
  static const String uploadDocuments = '/api/documents/upload';

  // ============ COURSE APIS ============
  static const String createCourse = '/api/courses';
  static const String updateCourse = '/api/courses';  // + /{courseId}
  static const String deleteCourse = '/api/courses';  // + /{courseId}
  static const String toggleAvailability = '/api/courses'; // + /{courseId}/toggle-availability
  static const String getTutorCourses = '/api/courses/tutor'; // + /{tutorProfileId}
  static const String getTutorCourseCards = '/api/courses/tutor'; // + /{tutorProfileId}/cards
  static const String getTutorCourseDetail = '/api/courses/tutor/detail'; // + /{courseId}
  static const String getAvailableCourses = '/api/courses/available';
  static const String searchCourses = '/api/courses/search';//filter with studentId=1
  static const String getCourseForStudent = '/api/courses'; // + /{courseId}/student
  static const String getAvailableCoursesForStudent = '/api/courses/student'; // + /{studentId}/available

  // ============ TUTOR DASHBOARD APIS ============
  static const String tutorDashboard = '/api/tutor/dashboard'; // + /{tutorId}
 // static const String tutorStudents = '/api/tutor/students'; // + /{tutorId}
  static const String studentDetail = '/api/tutor/students/detail'; // + /{connectionId}
  static const String searchStudents = '/api/tutor/students'; // + /{tutorId}/search
  static const String filterStudents = '/api/tutor/students/tutor'; // + /{tutorId}/students/filter

  // ============ STUDENT DASHBOARD APIS ============
  static const String studentDashboard = '/api/student/dashboard'; // + /{studentId}
  static const String topTutors = '/api/student/top-tutors'; // + /{studentId}?limit=10
  static const String tutorProfileView = '/api/student/tutor'; // + /{studentId}/{tutorId}/profile
  static const String getalltutor = '/api/student/tutors/all'; // + /{studentId}


  // ============ FAVORITE APIS ============
  static const String addFavorite = '/api/student/favorites'; // + /{studentId}/add/{courseId}
  static const String removeFavorite = '/api/student/favorites'; // + /{studentId}/remove/{courseId}
  static const String getFavorites = '/api/student/favorites'; // + /{studentId}
//  static const String checkFavorite = '/api/student/favorites'; // + /{studentId}/check/{courseId}

  // ============ RATING APIS ============
  static const String submitRating = '/api/student/ratings/submit';
 // static const String updateRating = '/api/student/ratings'; // + /{ratingId}
  static const String getCourseReviews = '/api/student/ratings/course'; // + /{courseId}/reviews
  static const String getTutorRatingSummary = '/api/tutor/ratings'; // + /{tutorId}/summary
  static const String getTutorFilterOptions = '/api/tutor/ratings'; // + /{tutorId}/filter-options
  static const String getTopRatedCourses = '/api/tutor/ratings'; // + /{tutorId}/top-courses
  static const String getReviewDetail = '/api/tutor/ratings/review'; // + /{reviewId}

  // ============ CONNECTION APIS ============
  static const String requestConnection = '/api/connections/request';
  static const String tutorRespond = '/api/connections'; // + /{connectionId}/tutor-respond
  static const String studentRespond = '/api/connections'; // + /{connectionId}/student-respond
  static const String disconnect = '/api/connections'; // + /{connectionId}/disconnect
  static const String studentCancel = '/api/connections'; // + /{connectionId}/student-cancel
  static const String getStudentConnections = '/api/connections/student'; // + /{studentId}
  static const String getTutorConnections = '/api/connections/tutor'; // + /{tutorId}
  static const String getTutorConfirmedConnections = '/api/connections/tutor'; // + /{tutorId}/confirmed
  static const String getStudentConfirmedConnections = '/api/connections/student'; // + /{studentId}/confirmed
  static const String getPendingRequests = '/api/connections/tutor'; // + /{tutorId}/pending
  static const String getNegotiations = '/api/connections/tutor'; // + /{tutorId}/negotiations
  static const String getTutorBids = '/api/connections/tutor'; // + /{tutorId}/course/{courseId}/bids
  static const String getTutorBidForStudent = '/api/connections/tutor'; // + /{tutorId}/course/{courseId}/student/{studentId}/bid
  static const String getStudentBids = '/api/connections/student'; // + /{studentId}/course/{courseId}/bids
  static const String getStatusByCourseStudent = '/api/connections/status-by-course-student';
  // static const String getTutorBidsForCourse = '/api/connections/tutor';
  // static const String getConnectionStatus = '/api/connections/student'; // + /{studentId}/status/{connectionId}

  // ============ BLOCK/REPORT APIS ============
  static const String blockTutor = '/api/student/block'; // + /{studentId}/block/{tutorId}
  static const String unblockTutor = '/api/student/block'; // + /{studentId}/unblock/{tutorId}
  static const String getBlockedList = '/api/student/block'; // + /{studentId}/list
  static const String checkBlocked = '/api/student/block'; // + /{studentId}/check/{tutorId}
 //old one
  static const String reportTutor = '/api/student/block/report';

  // NEW — Student → Tutor reports  
  static const String createReport = '/api/reports';                // ?studentId={id}
  static const String uploadReportEvidence = '/api/reports/upload-evidence'; // ?studentId={id}
  static const String getMyReports = '/api/reports/my';             // ?studentId={id}

  //  NEW — Tutor → Student reports
  static const String createStudentReport = '/api/tutor/student-reports';
  static const String uploadStudentReportEvidence = '/api/tutor/student-reports/upload-evidence';
  static const String getMyStudentReports = '/api/tutor/student-reports/my';
  // static const String getMyReports = '/api/student/block'; // + /{studentId}/reports

  // ============ CHAT APIS ============
  static const String getChatRoom = '/api/chat/room'; // + /{connectionId}
  static const String getUserChatRooms = '/api/chat/rooms'; // + /{userId}
  static const String sendMessage = '/api/chat/messages/send';
  static const String getMessages = '/api/chat/messages'; // + /{roomId}
  static const String markAsRead = '/api/chat/rooms'; // + /{roomId}/read-all
  static const String getUnreadCount = '/api/chat/unread-count'; // + /{userId}
  static const String deleteMessage = '/api/chat/messages'; // + /{messageId}
  static const String checkChatAvailable = '/api/chat/available'; // + /{connectionId}
  static const String getSharedChatRoom = '/api/chat/shared-room'; //?studentId={stduserid}&tutorId={tutoeuserid}&userId={senderid}
  static const String uploadAudio = '/api/chat/upload/audio';
  static const String uploadFile = '/api/chat/upload/file';

  // ============ ACCOUNT STATUS APIS ============
  static const String getAccountStatus = '/api/account';           // + /{userId}/status
  static const String deactivateTutor = '/api/account/tutor';      // + /{tutorId}/deactivate
  static const String reactivateTutor = '/api/account/tutor';      // + /{tutorId}/reactivate


  // ============ NOTIFICATION APIS ============
  static const String registerDeviceToken = '/api/notifications/register-token';
  static const String removeDeviceToken = '/api/notifications/remove-token';
  static const String markNotifReadByRoom = '/api/notifications/room';

  // In-app notification history
  static const String getUserNotifications = '/api/notifications/user';       // + /{userId}
  static const String getNotifUnreadCount = '/api/notifications/user';        // + /{userId}/unread-count
  static const String markNotifRead = '/api/notifications';                   // + /{id}/read?userId=X
  static const String markAllNotifRead = '/api/notifications/user';           // + /{userId}/read-all
  static const String deleteNotif = '/api/notifications';                     // + /{id}?userId=X

  // ============ HELPER METHODS ============
  static String getFullUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }

// ============ WEB SOCKET ============
  static String get wsUrl {
    String base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    String wsBase = base.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');


    return '$wsBase/ws/websocket';
  }

  static String getFullUrlWithParams(String endpoint, Map<String, String> params) {
    String url = '$baseUrl$endpoint';
    if (params.isNotEmpty) {
      url += '?' + params.entries.map((e) => '${e.key}=${e.value}').join('&');
    }
    return url;
  }
}