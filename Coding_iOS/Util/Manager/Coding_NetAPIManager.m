//
//  Coding_NetAPIManager.m
//  Coding_iOS
//
//  Created by 王 原闯 on 14-7-30.
//  Copyright (c) 2014年 Coding. All rights reserved.
//

#import "Coding_NetAPIManager.h"
#import "JDStatusBarNotification.h"
#import "UnReadManager.h"
#import <NYXImagesKit/NYXImagesKit.h>
#import <MMMarkdown/MMMarkdown.h>
#import "MBProgressHUD+Add.h"
#import "Register.h"
#import "ResourceReference.h"
#import "MRPRPreInfo.h"
#import "UserServiceInfo.h"
#import "Team.h"
#import "TeamMember.h"
#import "ProjectServiceInfo.h"
#import "CodingVipTipManager.h"
#import "EAWiki.h"

@implementation Coding_NetAPIManager
+ (instancetype)sharedManager {
    static Coding_NetAPIManager *shared_manager = nil;
    static dispatch_once_t pred;
	dispatch_once(&pred, ^{
        shared_manager = [[self alloc] init];
    });
	return shared_manager;
}
#pragma mark UnRead
- (void)request_UnReadCountWithBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/user/unread-count" withParams:nil withMethodType:Get autoShowError:NO andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Notification label:@"Tab首页的红点通知"];
            
            id resultData = [data valueForKeyPath:@"data"];
            block(resultData, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_UnReadNotificationsWithBlock:(void (^)(id data, NSError *error))block{
    NSMutableDictionary *notificationDict = [[NSMutableDictionary alloc] init];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/notification/unread-count" withParams:@{@"type" : @(0)} withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
//            @我的
            [notificationDict setObject:[data valueForKeyPath:@"data"] forKey:kUnReadKey_notification_AT];
            [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/notification/unread-count" withParams:@{@"type" : @[@(1), @(2)]} withMethodType:Get andBlock:^(id dataComment, NSError *errorComment) {
                if (dataComment) {
//                    评论
                    [notificationDict setObject:[dataComment valueForKeyPath:@"data"] forKey:kUnReadKey_notification_Comment];
                    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/notification/unread-count" withParams:@{@"type" : @[@(4),@(6)]} withMethodType:Get andBlock:^(id dataSystem, NSError *errorSystem) {
                        if (dataSystem) {
//                            系统
                            [MobClick event:kUmeng_Event_Request_Notification label:@"消息页面的红点通知"];

                            [notificationDict setObject:[dataSystem valueForKeyPath:@"data"] forKey:kUnReadKey_notification_System];
                            block(notificationDict, nil);
                        }else{
                            block(nil, errorSystem);
                        }
                    }];
                }else{
                    block(nil, errorComment);
                }
            }];
        }else{
            block(nil, error);
        }
    }];
}
#pragma mark Login
- (void)request_Login_With2FA:(NSString *)otpCode andBlock:(void (^)(id data, NSError *error))block{
    if (otpCode.length <= 0) {
        return;
    }
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/check_two_factor_auth_code" withParams:@{@"code" : otpCode} withMethodType:Post andBlock:^(id data, NSError *error) {
        id resultData = [data valueForKeyPath:@"data"];
        if (resultData) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"登录_2FA码"];

            User *curLoginUser = [NSObject objectOfClass:@"User" fromJSON:resultData];
            if (curLoginUser) {
                [Login doLogin:resultData];
            }
            block(curLoginUser, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_Login_WithPath:(NSString *)path Params:(id)params andBlock:(void (^)(id data, NSError *error))block{     
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Post autoShowError:NO andBlock:^(id data, NSError *error) {
        id resultData = [data valueForKeyPath:@"data"];
        if (resultData) {
            [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/user/unread-count" withParams:nil withMethodType:Get autoShowError:NO andBlock:^(id data_check, NSError *error_check) {//检查当前账号未设置邮箱和GK
                if (error_check.userInfo[@"msg"][@"user_need_activate"]) {
                    block(nil, error_check);
                }else{
                    [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"登录_密码"];
                    
                    User *curLoginUser = [NSObject objectOfClass:@"User" fromJSON:resultData];
                    if (curLoginUser) {
                        [Login doLogin:resultData];
                    }
                    block(curLoginUser, nil);
                }
            }];
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_Login_With_UMSocialResponse:(UMSocialResponse *)resp andBlock:(void (^)(id data, NSError *error))block{
    NSMutableDictionary *params = @{}.mutableCopy;
    params[@"account"] = resp.unionId;
    params[@"oauth_access_token"] = resp.accessToken;
    params[@"response"] = [NSString stringWithFormat:@"{\"access_token\":\"%@\",\"openid\":\"%@\"}", resp.accessToken, resp.openid];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/oauth/wechat/mobile/login" withParams:params withMethodType:Post autoShowError:NO andBlock:^(id data, NSError *error) {
        id resultData = [data valueForKeyPath:@"data"];
        if (resultData) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"登录_第三方登录"];
            
            User *curLoginUser = [NSObject objectOfClass:@"User" fromJSON:resultData];
            if (curLoginUser) {
                [Login doLogin:resultData];
            }
            block(curLoginUser, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_Register_V2_WithParams:(NSDictionary *)params andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = @"api/v2/account/register";
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Post andBlock:^(id data, NSError *error) {
        id resultData = [data valueForKeyPath:@"data"];
        if (resultData) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"注册_V2"];
            
            User *curLoginUser = [NSObject objectOfClass:@"User" fromJSON:resultData];
            if (curLoginUser) {
                [Login doLogin:resultData];
            }
            block(curLoginUser, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_CaptchaNeededWithPath:(NSString *)path andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path  withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"是否需要验证码"];

            id resultData = [data valueForKeyPath:@"data"];
            block(resultData, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_SetPasswordToPath:(NSString *)path params:(NSDictionary *)params andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"激活or重置密码"];

            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_CheckPhoneCodeWithPhone:(NSString *)phone code:(NSString *)code type:(PurposeType)type block:(void (^)(id data, NSError *error))block{
    NSString *path = @"api/account/register/check_phone_code";
    NSMutableDictionary *params = @{@"phone": phone,
                                    @"code": code}.mutableCopy;
    switch (type) {
        case PurposeToRegister:
            params[@"type"] = @"register";
            break;
        case PurposeToPasswordActivate:
            params[@"type"] = @"activate";
            break;
        case PurposeToPasswordReset:
            params[@"type"] = @"reset";
            break;
    }
    
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"校验手机验证码"];
        }
        block(data, error);
    }];
}
- (void)request_ActivateBySetGlobal_key:(NSString *)global_key block:(void (^)(id data, NSError *error))block{
    NSString *path = @"api/account/global_key/acitvate";
    NSDictionary *params = @{@"global_key": global_key};
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Post andBlock:^(id data, NSError *error) {
        id resultData = [data valueForKeyPath:@"data"];
        if (resultData) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"激活账号_设置GK"];
            
            User *curLoginUser = [NSObject objectOfClass:@"User" fromJSON:resultData];
            if (curLoginUser) {
                [Login doLogin:resultData];
            }
            block(curLoginUser, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_SendActivateEmail:(NSString *)email block:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/account/register/email/send" withParams:@{@"email": email} withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            if ([(NSNumber *)data[@"data"] boolValue]) {
                [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"激活账号_重发激活邮件"];
                
                block(data, nil);
            }else{
                [NSObject showHudTipStr:@"发送失败"];
                block(nil, nil);
            }
        }else{
            block(nil, error);
        }
    }];
}
#pragma mark Project
- (void)request_Projects_WithObj:(Projects *)projects andBlock:(void (^)(Projects *data, NSError *error))block{
    projects.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[projects toPath] withParams:[projects toParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        projects.isLoading = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_RootList label:@"项目列表"];

            id resultData = [data valueForKeyPath:@"data"];
            Projects *pros = [NSObject objectOfClass:@"Projects" fromJSON:resultData];
            block(pros, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_ProjectsCatergoryAndCounts_WithObj:(ProjectCount *)pCount andBlock:(void (^)(ProjectCount *data, NSError *error))block
{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/project_count" withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_RootList label:@"筛选列表"];
            
            id resultData = [data valueForKeyPath:@"data"];
           ProjectCount *prosC = [NSObject objectOfClass:@"ProjectCount" fromJSON:resultData];
            block(prosC, nil);
        }else{
            block(nil, error);
        }
    }];

}

- (void)request_ProjectsHaveTasks_WithObj:(Projects *)projects andBlock:(void (^)(id data, NSError *error))block{
    projects.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/projects" withParams:[projects toParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        
        if (data) {
            id resultData = [data valueForKeyPath:@"data"];
            Projects *pros = [NSObject objectOfClass:@"Projects" fromJSON:resultData];
            [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/tasks/projects/count" withParams:nil withMethodType:Get andBlock:^(id datatasks, NSError *errortasks) {
                projects.isLoading = NO;
                if (datatasks) {
                    [MobClick event:kUmeng_Event_Request_RootList label:@"有任务的项目列表"];

                    NSMutableArray *list = [[NSMutableArray alloc] init];
                    NSArray *taskProArray = [datatasks objectForKey:@"data"];
                    for (NSDictionary *dict in taskProArray) {
                        for (Project *curPro in pros.list) {
                            if (curPro.id.intValue == ((NSNumber *)[dict objectForKey:@"project"]).intValue) {
                                curPro.done = [dict objectForKey:@"done"];
                                curPro.processing = [dict objectForKey:@"processing"];
                                [list addObject:curPro];
                            }
                        }
                    }
                    pros.list = list;
                    block(pros, nil);
                }else{
                    block(nil, error);
                }
            }];
        }else{
            projects.isLoading = NO;
            block(nil, error);
        }
    }];
}
- (void)request_Project_UpdateVisit_WithObj:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[project toUpdateVisitPath] withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Notification label:@"更新项目为已读"];

            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_ProjectDetail_WithObj:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    project.isLoadingDetail = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[project toDetailPath] withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        project.isLoadingDetail = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"获取项目详情"];

            id resultData = [data valueForKeyPath:@"data"];
            Project *resultA = [NSObject objectOfClass:@"Project" fromJSON:resultData];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_ProjectActivityList_WithObj:(ProjectActivities *)proActs andBlock:(void (^)(NSArray *data, NSError *error))block{
    proActs.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[proActs toPath] withParams:[proActs toParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        proActs.isLoading = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:[NSString stringWithFormat:@"项目动态_%@", proActs.type]];

            id resultData = [data valueForKeyPath:@"data"];
            NSArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"ProjectActivity"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_ProjectMember_Quit:(ProjectMember *)curMember andBlock:(void (^)(id data, NSError *error))block{
    if (curMember.user_id.intValue == [Login curLoginUser].id.intValue) {
        [NSObject showStatusBarQueryStr:@"正在退出项目"];
        [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curMember toQuitPath] withParams:nil withMethodType:Post andBlock:^(id data, NSError *error) {
            if (data) {
                [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"退出项目"];

                [NSObject showStatusBarSuccessStr:@"退出项目成功"];
                block(curMember, nil);
            }else{
                [NSObject showStatusBarError:error];
                block(nil, error);
            }
        }];
    }else{
        [NSObject showStatusBarQueryStr:@"正在移除成员"];
        [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curMember toKickoutPath] withParams:nil withMethodType:Post andBlock:^(id data, NSError *error) {
            if (data) {
                [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"移除成员"];

                [NSObject showStatusBarSuccessStr:@"移除成员成功"];
                block(curMember, nil);
            }else{
                [NSObject showStatusBarError:error];
                block(nil, error);
            }
        }];
    }
}
- (void)request_Project_Pin:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/projects/pin"];
    NSDictionary *params = @{@"ids": project.id.stringValue};
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:project.pin.boolValue? Delete: Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"设置常用项目"];

            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

-(void)request_NewProject_WithObj:(Project *)project image:(UIImage *)image andBlock:(void (^)(NSString *, NSError *))block{
    [NSObject showStatusBarQueryStr:@"正在创建项目"];
    NSDictionary *fileDic;
    if (image) {
        fileDic = @{@"image":image,@"name":@"icon",@"fileName":@"icon.jpg"};
    }
    
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[project toProjectPath] file:fileDic withParams:[project toCreateParams] withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"创建项目"];

            [NSObject showStatusBarSuccessStr:@"创建项目成功"];
            id resultData = [data valueForKeyPath:@"data"];
            block(resultData, nil);
        }else{
            [NSObject showStatusBarError:error];
            block(nil, error);
        }
    }];
}

-(void)request_UpdateProject_WithObj:(Project *)project andBlock:(void (^)(Project *, NSError *))block{
    [NSObject showStatusBarQueryStr:@"正在更新项目"];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[project toUpdatePath] withParams:[project toUpdateParams] withMethodType:Put andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"设置项目"];

            [NSObject showStatusBarSuccessStr:@"更新项目成功"];
            id resultData = [data valueForKeyPath:@"data"];
            Project *resultA = [NSObject objectOfClass:@"Project" fromJSON:resultData];
            block(resultA, nil);
        }else{
            [NSObject showStatusBarError:error];
            block(nil, error);
        }
    }];
}

-(void)request_UpdateProject_WithObj:(Project *)project icon:(UIImage *)icon andBlock:(void (^)(id, NSError *))block progerssBlock:(void (^)(CGFloat))progress{
    [[CodingNetAPIClient sharedJsonClient] uploadImage:icon path:[project toUpdateIconPath] name:@"file" successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
        id error = [self handleResponse:responseObject];
        if (error) {
            block(nil, error);
        }else{
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"更改项目图标"];

            block(responseObject, nil);
            [NSObject showStatusBarSuccessStr:@"更新项目图标成功"];
        }
    } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
        block(nil, error);
        [NSObject showStatusBarError:error];
    } progerssBlock:progress];
}

- (void)request_DeleteProject_WithObj:(Project *)project passCode:(NSString *)passCode type:(VerifyType)type andBlock:(void (^)(Project *data, NSError *error))block{
    if (!project.name || !passCode) {
        return;
    }
    NSDictionary *params;
    if (type == VerifyTypePassword) {
        params = @{
                   @"name": project.name,
                   @"two_factor_code": [passCode sha1Str]
                   };
    }else if (type == VerifyTypeTotp){
        params = @{
                   @"name": project.name,
                   @"two_factor_code": passCode
                   };
    }else{
        return;
    }
    [NSObject showStatusBarQueryStr:@"正在删除项目"];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[project toDeletePath] withParams:params withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"删除项目"];

            [NSObject showStatusBarSuccessStr:@"删除项目成功"];
            block(data, nil);
        }else{
            [NSObject showStatusBarError:error];
            block(nil, error);
        }
    }];
}
- (void)request_ArchiveProject_WithObj:(Project *)project passCode:(NSString *)passCode type:(VerifyType)type andBlock:(void (^)(Project *data, NSError *error))block{
    NSDictionary *params = @{@"two_factor_code": (type == VerifyTypePassword? [passCode sha1Str]: passCode)};;
    [NSObject showStatusBarQueryStr:@"正在归档项目"];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[project toArchivePath] withParams:params withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"归档项目"];
            
            [NSObject showStatusBarSuccessStr:@"归档项目成功"];
            block(data, nil);
        }else{
            [NSObject showStatusBarError:error];
            block(nil, error);
        }
    }];
}

- (void)request_TransferProject:(Project *)project toUser:(User *)user passCode:(NSString *)passCode type:(VerifyType)type andBlock:(void (^)(Project *data, NSError *error))block{
    if (project.id.stringValue.length <= 0 || user.global_key.length <= 0|| passCode.length <= 0) {
        return;
    }
    NSString *path = [NSString stringWithFormat:@"api/project/%@/transfer_to/%@", project.id.stringValue, user.global_key];
    NSDictionary *params;
    if (type == VerifyTypePassword) {
        params = @{@"two_factor_code": [passCode sha1Str]};
    }else if (type == VerifyTypeTotp){
        params = @{@"two_factor_code": passCode};
    }else{
        return;
    }
    [NSObject showStatusBarQueryStr:@"正在转让项目"];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Put andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"转让项目"];
            
            [NSObject showStatusBarSuccessStr:@"转让项目成功"];
            block(data, nil);
        }else{
            [NSObject showStatusBarError:error];
            block(nil, error);
        }
    }];
}

- (void)request_ProjectTaskList_WithObj:(Tasks *)tasks andBlock:(void (^)(Tasks *data, NSError *error))block{
    tasks.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[tasks toRequestPath] withParams:[tasks toParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        tasks.isLoading = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_RootList label:@"任务_列表"];

            id resultData = [data valueForKeyPath:@"data"];
            Tasks *resultTasks = [NSObject objectOfClass:@"Tasks" fromJSON:resultData];
            block(resultTasks, nil);
        }else{
            block(nil, error);
        }

    }];
}
- (void)request_ProjectMembers_WithObj:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    project.isLoadingMember = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[project toMembersPath] withParams:[project toMembersParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        project.isLoadingMember = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"项目成员"];

            id resultData = [data valueForKeyPath:@"data"];
            if (resultData) {//存储到本地
                [NSObject saveResponseData:resultData toPath:[project localMembersPath]];
            }
            resultData = [resultData objectForKey:@"list"];

            NSMutableArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"ProjectMember"];
            [resultA sortUsingComparator:^NSComparisonResult(ProjectMember *obj1, ProjectMember *obj2) {
                if ([obj1.user_id isEqualToNumber:[Login curLoginUser].id]) {
                    return NSOrderedAscending;
                }else if ([obj2.user_id isEqualToNumber:[Login curLoginUser].id]){
                    return NSOrderedDescending;
                }else{
                    return obj1.type.intValue < obj2.type.intValue;
                }
            }];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_ProjectMembersHaveTasks_WithObj:(Project *)project andBlock:(void (^)(NSArray *data, NSError *error))block{
    project.isLoadingMember = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[project toMembersPath] withParams:[project toMembersParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            id resultData = [data valueForKeyPath:@"data"];
            resultData = [resultData objectForKey:@"list"];
            NSArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"ProjectMember"];
            
            [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[NSString stringWithFormat:@"api/project/%d/task/user/count", project.id.intValue] withParams:nil withMethodType:Get andBlock:^(id datatasks, NSError *errortasks) {
                project.isLoadingMember = NO;
                if (datatasks) {
                    [MobClick event:kUmeng_Event_Request_Get label:@"有任务的项目成员"];

                    NSMutableArray *list = [[NSMutableArray alloc] init];
                    
                    NSArray *taskMembersArray = [datatasks objectForKey:@"data"];
                    for (ProjectMember *curMember in resultA) {
                        BOOL hasTask = NO;
                        for (NSDictionary *dict in taskMembersArray) {
                            if (curMember.user_id.intValue == ((NSNumber *)[dict objectForKey:@"user"]).intValue) {
                                curMember.done = [dict objectForKey:@"done"];
                                curMember.processing = [dict objectForKey:@"processing"];
                                hasTask = YES;
                                break;
                            }
                        }
                        if (hasTask) {
                            if (curMember.user_id.integerValue == [Login curLoginUser].id.integerValue) {
                                [list insertObject:curMember atIndex:0];
                            }else{
                                [list addObject:curMember];
                            }
                        }else if (curMember.user_id.integerValue == [Login curLoginUser].id.integerValue){
                            [list insertObject:curMember atIndex:0];
                        }
                    }
                    block(list, nil);
                }else{
                    block(nil, errortasks);
                }
            }];
        }else{
            project.isLoadingMember = NO;
            block(nil, error);
        }
    }];
}
- (void)request_EditAliasOfMember:(ProjectMember *)curMember inProject:(Project *)curPro andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/project/%@/members/update_alias/%@", curPro.id, curMember.user_id];
    NSDictionary *params = @{@"alias": curMember.editAlias};
    [NSObject showStatusBarQueryStr:@"正在设置备注"];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"项目成员_设置备注名"];
            
            [NSObject showStatusBarSuccessStr:@"备注设置成功"];
        }else{
            [NSObject showStatusBarError:error];
        }
        block(data, error);
    }];
}
- (void)request_EditTypeOfMember:(ProjectMember *)curMember inProject:(Project *)curPro andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/project/%@/member/%@/%@", curPro.id, curMember.user.global_key, curMember.editType];
    [NSObject showStatusBarQueryStr:@"正在设置成员类型"];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"项目成员_设置成员类型"];
            
            [NSObject showStatusBarSuccessStr:@"成员类型设置成功"];
        }else{
            [NSObject showStatusBarError:error];
        }
        block(data, error);
    }];
}

- (void)request_ProjectServiceInfo:(Project *)curPro andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/service_info", curPro.owner_user_name, curPro.name];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"项目_信息"];
            
            data = [NSObject arrayFromJSON:data[@"data"] ofObjects:@"ProjectServiceInfo"];
        }
        block(data, error);
    }];
}

#pragma mark Team
- (void)request_JoinedTeamsBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/team/joined" withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"团队_列表"];

            data = [NSObject arrayFromJSON:data[@"data"] ofObjects:@"Team"];
        }
        block(data, error);
    }];
}

- (void)request_DetailOfTeam:(Team *)team andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/team/%@/get", team.global_key];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"团队_详情"];
            
            data = [NSObject objectOfClass:@"Team" fromJSON:data[@"data"]];
        }
        block(data, error);
    }];
}

- (void)request_ProjectsInTeam:(Team *)team isJoined:(BOOL)isJoined andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/team/%@/projects/%@", team.global_key, isJoined? @"joined": @"unjoined"];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"团队_项目列表"];
            
            data = [NSObject arrayFromJSON:data[@"data"] ofObjects:@"Project"];
        }
        block(data, error);
    }];
}
- (void)request_MembersInTeam:(Team *)team andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/team/%@/members", team.global_key];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"团队_项目列表"];
            
            data = [NSObject arrayFromJSON:data[@"data"] ofObjects:@"TeamMember"];
        }
        block(data, error);
    }];
}

#pragma mark MRPR
- (void)request_MRPRS_WithObj:(MRPRS *)curMRPRS andBlock:(void (^)(MRPRS *data, NSError *error))block{
    curMRPRS.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curMRPRS toPath] withParams:[curMRPRS toParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        curMRPRS.isLoading = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"MRPR_列表"];

            id resultData = [data valueForKeyPath:@"data"];
            MRPRS *resultA = [NSObject objectOfClass:@"MRPRS" fromJSON:resultData];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];

}

- (void)request_MRPRBaseInfo_WithObj:(MRPR *)curMRPR andBlock:(void (^)(MRPRBaseInfo *data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curMRPR toBasePath] withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"MRPR_详情页面"];

            id resultData = [data valueForKeyPath:@"data"];
            MRPRBaseInfo *resultA = [NSObject objectOfClass:@"MRPRBaseInfo" fromJSON:resultData];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_MRPRPreInfo_WithObj:(MRPR *)curMRPR andBlock:(void (^)(MRPRPreInfo *data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curMRPR toPrePath] withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"MRPR_详情页面"];
            
            id resultData = [data valueForKeyPath:@"data"];
            MRPRPreInfo *resultA = [NSObject objectOfClass:@"MRPRPreInfo" fromJSON:resultData];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_MRReviewerInfo_WithObj:(MRPR *)curMRPR andBlock:(void (^)(ReviewersInfo *data, NSError *error))block {
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curMRPR toReviewersPath] withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"MRPR_详情页面"];
            
            id resultData = [data valueForKeyPath:@"data"];
            ReviewersInfo *resultA = [NSObject objectOfClass:@"ReviewersInfo" fromJSON:resultData];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_MRPRCommits_WithObj:(MRPR *)curMRPR andBlock:(void (^)(NSArray *data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curMRPR toCommitsPath] withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"MRPR_提交记录列表"];

            id resultData = [data valueForKeyPath:@"data"];
            NSArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"Commit"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_MRPRFileChanges_WithObj:(MRPR *)curMRPR andBlock:(void (^)(FileChanges *data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curMRPR toFileChangesPath] withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"MRPR_文件改动列表"];

            id resultData = [data valueForKeyPath:@"data"];
            FileChanges *resultA = [NSObject objectOfClass:@"FileChanges" fromJSON:resultData];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_MRPRAccept:(MRPR *)curMRPR andBlock:(void (^)(id data, NSError *error))block{
    [NSObject showStatusBarQueryStr:@"正在合并请求"];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curMRPR toAcceptPath] withParams:[curMRPR toAcceptParams] withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"MRPR_合并"];

            [NSObject showStatusBarSuccessStr:@"合并请求成功"];
            block(data, nil);
        }else{
            [NSObject showStatusBarError:error];
            block(nil, error);
        }
    }];
}
- (void)request_MRPRRefuse:(MRPR *)curMRPR andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curMRPR toRefusePath] withParams:nil withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"MRPR_拒绝"];

            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_MRPRAuthorization:(MRPR *)curMRPR andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curMRPR toAuthorizationPath] withParams:nil withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"MRPR_授权"];

            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_MRPRCancel:(MRPR *)curMRPR andBlock:(void (^)(id data, NSError *error))block {
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curMRPR toCancelPath] withParams:nil withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"MRPR_取消合并"];
            
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];

}

- (void)request_MRPRCancelAuthorization:(MRPR *)curMRPR andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curMRPR toAuthorizationPath] withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"MRPR_取消授权"];
            
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_CommitInfo_WithUserGK:(NSString *)userGK projectName:(NSString *)projectName commitId:(NSString *)commitId andBlock:(void (^)(CommitInfo *data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/git/commit/%@", userGK, projectName, commitId];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"某次提交记录的详情"];

            id resultData = [data valueForKeyPath:@"data"];
            CommitInfo *resultA = [NSObject objectOfClass:@"CommitInfo" fromJSON:resultData];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_PostCommentWithPath:(NSString *)path params:(NSDictionary *)params andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"LineNote_评论_添加"];

            NSString *noteable_type = [params objectForKey:@"noteable_type"];
            if ([noteable_type isEqualToString:@"MergeRequestBean"] ||
                [noteable_type isEqualToString:@"PullRequestBean"] ||
                [noteable_type isEqualToString:@"Commit"]) {
                id resultData = [data valueForKeyPath:@"data"];
                ProjectLineNote *note = [NSObject objectOfClass:@"ProjectLineNote" fromJSON:resultData];
                block(note, nil);
            }else{
                block(data, nil);
            }
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_DeleteLineNote:(NSNumber *)lineNoteId inProject:(NSString *)projectName ofUser:(NSString *)userGK andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/git/line_notes/%@", userGK, projectName, lineNoteId.stringValue];
    [self request_DeleteLineNoteWithPath:path andBlock:block];
}

- (void)request_DeleteLineNoteWithPath:(NSString *)path andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"LineNote_评论_删除"];
            
            block(data, nil);
            
        }else{
            block(nil, error);
        }
    }];
}
#pragma mark File
- (void)request_Folders:(ProjectFolders *)folders inProject:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    folders.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[folders toFoldersPathWithObj:project.id] withParams:[folders toFoldersParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            id resultData = [data valueForKeyPath:@"data"];
            ProjectFolders *proFolders = [NSObject objectOfClass:@"ProjectFolders" fromJSON:resultData];
            {//默认文件夹
                ProjectFolder *defaultFolder = [ProjectFolder defaultFolder];
                ProjectFolder *shareFolder = [ProjectFolder shareFolder];
                [proFolders.list insertObject:defaultFolder atIndex:0];
                [proFolders.list insertObject:shareFolder atIndex:0];
            }
            //补全 project_id
            for (ProjectFolder *folder in proFolders.list) {
                folder.project_id = project.id;
                for (ProjectFolder *sub_folder in folder.sub_folders) {
                    sub_folder.project_id = project.id;
                }
            }
            [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[folders toFoldersCountPathWithObj:project.id] withParams:nil withMethodType:Get andBlock:^(id countData, NSError *countError) {
                if (countData) {
                    [MobClick event:kUmeng_Event_Request_Get label:@"文件夹列表"];
                   
                    //每个文件夹内的文件数量
                    countData = countData[@"data"];
                    NSArray *countArray = [countData valueForKey:@"folders"];
                    NSMutableDictionary *countDict = [[NSMutableDictionary alloc] initWithCapacity:countArray.count];
                    for (NSDictionary *item in countArray) {
                        [countDict setObject:[item objectForKey:@"count"] forKey:[item objectForKey:@"folder"]];
                    }
                    countDict[@(-1)] = countData[@"shareCount"];//shareFolder 特殊处理下
                    
                    for (ProjectFolder *folder in proFolders.list) {
                        folder.count = [countDict objectForKey:folder.file_id];
                        for (ProjectFolder *sub_folder in folder.sub_folders) {
                            sub_folder.count = [countDict objectForKey:sub_folder.file_id];
                        }
                    }
                    for (ProjectFolder *folder in folders.list) {//原来文件夹的文件数也更新一下
                        folder.count = [countDict objectForKey:folder.file_id];
                        for (ProjectFolder *sub_folder in folder.sub_folders) {
                            sub_folder.count = [countDict objectForKey:sub_folder.file_id];
                        }
                    }
                    folders.isLoading = NO;
                    block(proFolders, nil);
                }else{
                    folders.isLoading = NO;
                    block(nil, countError);
                }
            }];
            
        }else{
            folders.isLoading = NO;
            block(nil, error);
        }
    }];
}
- (void)request_FilesInFolder:(ProjectFolder *)folder andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[folder toFilesPath] withParams:[folder toFilesParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"文件列表"];

            id resultData = [data valueForKeyPath:@"data"];
            ProjectFiles *files = [NSObject objectOfClass:@"ProjectFiles" fromJSON:resultData];
            for (ProjectFile *file in files.list) {
                file.project_id = folder.project_id;
            }
            block(files, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_DeleteFolder:(ProjectFolder *)folder andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[folder toDeletePath] withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"文件夹_删除"];

            block(folder, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_RenameFolder:(ProjectFolder *)folder andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[folder toRenamePath] withParams:nil withMethodType:Put andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"文件夹_重命名"];

            block(folder, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_DeleteFiles:(NSArray *)fileIdList inProject:(NSNumber *)project_id andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/project/%@/file/delete", project_id.stringValue];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:@{@"fileIds" : fileIdList} withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"文件_删除"];

            block(fileIdList, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_MoveFiles:(NSArray *)fileIdList toFolder:(ProjectFolder *)folder andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[folder toMoveToPath] withParams:@{@"fileId": fileIdList} withMethodType:Put andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"文件_移动"];

            block(fileIdList, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_MoveFolder:(NSNumber *)folderId toFolder:(ProjectFolder *)folder inProject:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/folder/%@/move-to/%@", project.owner_user_name, project.name, folderId, folder.file_id];    
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Put andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"文件夹_移动"];
            
            block(folderId, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_CreatFolder:(NSString *)fileName inFolder:(ProjectFolder *)parentFolder inProject:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/project/%@/mkdir", project.id.stringValue];
    NSDictionary *params = @{@"name" : fileName,
                             @"parentId" : (parentFolder && parentFolder.file_id)? parentFolder.file_id.stringValue : @"0" };
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"文件夹_新建"];

            id resultData = [data valueForKeyPath:@"data"];
            ProjectFolder *createdFolder = [NSObject objectOfClass:@"ProjectFolder" fromJSON:resultData];
            createdFolder.project_id = project.id;
            block(createdFolder, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_FileDetail:(ProjectFile *)file andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[file toDetailPath] withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"文件详情"];

            id resultData = [data valueForKeyPath:@"data"];
            resultData = [resultData valueForKeyPath:@"file"];
            ProjectFile *detailFile = [NSObject objectOfClass:@"ProjectFile" fromJSON:resultData];
            if (file.project_id) {
                detailFile.project_id = file.project_id;
            }
            block(detailFile, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_FileContent:(ProjectFile *)file andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[file toDetailPath] withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"文件_获取内容"];
            
            id resultData = [data valueForKeyPath:@"data"];
            resultData = [resultData valueForKeyPath:@"content"];
            block(resultData, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_EditFile:(ProjectFile *)file withContent:(NSString *)contentStr andBlock:(void (^)(id data, NSError *error))block{
    if (!contentStr || !file.name) {
        return;
    }
    NSString *path = [NSString stringWithFormat:@"api/project/%@/files/%@/edit", file.project_id, file.file_id];
    NSDictionary *params = @{@"name" : file.name,
                             @"content" : contentStr};
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"文件_编辑内容"];
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_RenameFile:(ProjectFile *)file withName:(NSString *)nameStr andBlock:(void (^)(id data, NSError *error))block{
    if (!nameStr) {
        return;
    }
    NSString *path = [NSString stringWithFormat:@"api/project/%@/files/%@/rename", file.project_id, file.file_id];
    NSDictionary *params = @{@"name" : nameStr};
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Put andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"文件_重命名"];
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_ActivityListOfFile:(ProjectFile *)file andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[file toActivityListPath] withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"文件动态列表"];

            id resultData = [data valueForKeyPath:@"data"];
            NSMutableArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"ProjectActivity"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_VersionListOfFile:(ProjectFile *)file andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[file toHistoryListPath] withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"文件版本列表"];

            id resultData = [data valueForKeyPath:@"data"];
            NSMutableArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"FileVersion"];
            [resultA setValue:file.project_id forKey:@"project_id"];
            [resultA setValue:file.fileType forKey:@"fileType"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_DeleteComment:(NSNumber *)comment_id inFile:(ProjectFile *)file andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/project/%@/files/%@/comment/%@", file.project_id.stringValue, file.file_id.stringValue, comment_id.stringValue];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"文件_评论_删除"];

            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_RemarkFileVersion:(FileVersion *)curVersion withStr:(NSString *)remarkStr andBlock:(void (^)(id data, NSError *error))block{
    if (!remarkStr) {
        return;
    }
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curVersion toRemarkPath] withParams:@{@"remark" : remarkStr} withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"历史文件_修改备注"];

            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_DeleteFileVersion:(FileVersion *)curVersion andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curVersion toDeletePath] withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"历史文件_删除"];

            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_OpenShareOfFile:(ProjectFile *)file andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = @"api/share/create";
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:[file toShareParams] withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"文件_开启共享"];
            
            NSString *share_url = [[data valueForKey:@"data"] valueForKey:@"url"];
            block(share_url, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_CloseFileShareHash:(NSString *)hashStr andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/share/%@", hashStr];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"文件_关闭共享"];
            
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_OpenShareOfWiki:(EAWiki *)wiki andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = @"api/share/create";
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:[wiki toShareParams] withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"Wiki_开启共享"];
            
            NSString *share_url = [[data valueForKey:@"data"] valueForKey:@"url"];
            block(share_url, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_CloseWikiShareHash:(NSString *)hashStr andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/share/%@", hashStr];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"Wiki_关闭共享"];
            
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

#pragma mark Code
- (void)request_CodeTree:(CodeTree *)codeTree withPro:(Project *)project codeTreeBlock:(void (^)(id codeTreeData, NSError *codeTreeError))block{
    NSString *refAndPath = [NSString handelRef:codeTree.ref path:codeTree.path];
    NSString *treePath = [NSString stringWithFormat:@"api/user/%@/project/%@/git/tree/%@", project.owner_user_name, project.name, refAndPath];
    NSString *treeinfoPath = [NSString stringWithFormat:@"api/user/%@/project/%@/git/treeinfo/%@", project.owner_user_name, project.name, refAndPath];
    NSString *treeListPath = [NSString stringWithFormat:@"api/user/%@/project/%@/git/treelist/%@", project.owner_user_name, project.name, codeTree.ref];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:treePath withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            id resultData = [data valueForKeyPath:@"data"];
            CodeTree *rCodeTree = [NSObject objectOfClass:@"CodeTree" fromJSON:resultData];
            
            [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:treeinfoPath withParams:nil withMethodType:Get andBlock:^(id infoData, NSError *infoError) {
                if (infoData) {
                    infoData = [infoData valueForKey:@"data"];
                    infoData = [infoData valueForKey:@"infos"];
                    NSMutableArray *infoArray = [NSObject arrayFromJSON:infoData ofObjects:@"CodeTree_CommitInfo"];
                    [rCodeTree configWithCommitInfos:infoArray];
                    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:treeListPath withParams:nil withMethodType:Get andBlock:^(id listData, NSError *listError) {
                        if (listData) {
                            [MobClick event:kUmeng_Event_Request_Get label:@"代码目录"];
                            rCodeTree.treeList = listData[@"data"];
                            block(rCodeTree, nil);
                        }else{
                            block(nil, listError);
                        }
                    }];
                }else{
                    block(nil, infoError);
                }
            }];
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_CodeFile:(CodeFile *)codeFile withPro:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    NSString *filePath = [NSString stringWithFormat:@"api/user/%@/project/%@/git/blob/%@", project.owner_user_name, project.name, [NSString handelRef:codeFile.ref path:codeFile.path]];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:filePath withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"代码文件内容"];

            id resultData = [data valueForKey:@"data"];
            CodeFile *rCodeFile = [NSObject objectOfClass:@"CodeFile" fromJSON:resultData];
            rCodeFile.path = codeFile.path;
            block(rCodeFile, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_EditCodeFile:(CodeFile *)codeFile withPro:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    NSString *filePath = [NSString stringWithFormat:@"api/user/%@/project/%@/git/edit/%@", project.owner_user_name, project.name, [NSString handelRef:codeFile.ref path:codeFile.path]];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:filePath withParams:[codeFile toEditParams] withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"代码文件_修改"];
            
            block(data, nil);//{"code":0}
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_DeleteCodeFile:(CodeFile *)codeFile withPro:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    NSString *filePath = [NSString stringWithFormat:@"api/user/%@/project/%@/git/delete/%@", project.owner_user_name, project.name, [NSString handelRef:codeFile.ref path:codeFile.path]];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:filePath withParams:[codeFile toDeleteParams] withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"代码文件_删除"];
            
            block(data, nil);//{"code":0}
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_CodeBranchOrTagWithPath:(NSString *)path withPro:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[project toBranchOrTagPath:path] withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"(分支_标签)_列表"];

            id resultData = [data valueForKey:@"data"];
            NSArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"CodeBranchOrTag"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_Commits:(Commits *)curCommits withPro:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/git/commits/%@", project.owner_user_name, project.name, [NSString handelRef:curCommits.ref path:curCommits.path]];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:[curCommits toParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"提交记录_列表"];

            id resultData = [data valueForKey:@"data"];
            resultData = [resultData valueForKey:@"commits"];
            Commits *resultA = [NSObject objectOfClass:@"Commits" fromJSON:resultData];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_UploadAssets:(NSArray *)assets inCodeTree:(CodeTree *)codeTree withPro:(Project *)project andBlock:(void (^)(id data, NSError *error))block progerssBlock:(void (^)(CGFloat progressValue))progressBlock{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/git/upload/%@", project.owner_user_name, project.name, [NSString handelRef:codeTree.ref path:codeTree.path]];
    NSMutableDictionary *params = @{}.mutableCopy;
    params[@"message"] = @"Add files via upload";
    params[@"lastCommitSha"] = codeTree.headCommit.commitId;

    [[CodingNetAPIClient sharedJsonClient] uploadAssets:assets path:path name:@"files" params:params successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
        [MobClick event:kUmeng_Event_Request_Get label:@"代码文件_上传图片"];
        
        block(responseObject, nil);
    } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
        block(nil, error);
    } progerssBlock:^(CGFloat progressValue) {
        progressBlock(progressValue);
    }];
}

- (void)request_CreateCodeFile:(CodeFile *)codeFile withPro:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    NSString *filePath = [NSString stringWithFormat:@"api/user/%@/project/%@/git/new/%@", project.owner_user_name, project.name, [NSString handelRef:codeFile.ref path:codeFile.path]];

    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:filePath withParams:[codeFile toCreateParams] withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"代码文件_创建文本文件"];
            
            block(data, nil);//{"code":0}
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_CodeBranches_WithObj:(EACodeBranches *)curObj andBlock:(void (^)(EACodeBranches *data, NSError *error))block{
    curObj.isLoading = YES;
    //拿 branch 列表
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curObj toPath] withParams:[curObj toParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"分支管理_列表"];
            
            id resultData = [data valueForKeyPath:@"data"];
            EACodeBranches *resultA = [NSObject objectOfClass:@"EACodeBranches" fromJSON:resultData];
            if (resultA.list.count > 0) {
                //拿 branch 对应的 metrics
                void (^metricsQueryBlock)() = ^(){
                    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/git/branch_metrics", curObj.curPro.owner_user_name, curObj.curPro.name];
                    NSString *targetsStr = [[resultA.list valueForKeyPath:@"last_commit.commitId"] componentsJoinedByString:@","];
                    NSDictionary *params = @{@"base": curObj.defaultBranch.last_commit.commitId ?: @"",
                                             @"targets": targetsStr
                                             };
                    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Get andBlock:^(id dataM, NSError *errorM) {
                        if (dataM) {
                            dataM = dataM[@"data"];
                            for (CodeBranchOrTag *curB in resultA.list) {
                                curB.branch_metric = [NSObject objectOfClass:@"CodeBranchOrTagMetric" fromJSON:dataM[curB.last_commit.commitId]];
                            }
                            block(resultA, nil);
                        }else{
                            block(nil, errorM);
                        }
                        curObj.isLoading = NO;
                    }];
                };
                curObj.defaultBranch = curObj.defaultBranch ?: resultA.defaultBranch;
                if (!curObj.defaultBranch) {//请求 default 分支
                    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[NSString stringWithFormat:@"api/user/%@/project/%@/git/branches/default", curObj.curPro.owner_user_name, curObj.curPro.name] withParams:nil withMethodType:Get andBlock:^(id dataD, NSError *errorD) {
                        if (dataD) {
                            curObj.defaultBranch = [NSObject objectOfClass:@"CodeBranchOrTag" fromJSON:dataD[@"data"]];
                            metricsQueryBlock();
                        }else{
                            curObj.isLoading = NO;
                            block(nil, errorD);
                        }
                    }];
                }else{
                    metricsQueryBlock();
                }
            }else{
                curObj.isLoading = NO;
                block(resultA, nil);
            }
        }else{
            curObj.isLoading = NO;
            block(nil, error);
        }
    }];
}

- (void)request_DeleteCodeBranch:(CodeBranchOrTag *)curB inProject:(Project *)curP andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/git/branches/delete", curP.owner_user_name, curP.name];
    NSDictionary *params = @{@"branch_name": curB.name};
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"分支管理_删除"];
        }
        block(data, error);
    }];
}

- (void)request_CodeReleases_WithObj:(EACodeReleases *)curObj andBlock:(void (^)(EACodeReleases *data, NSError *error))block{
    curObj.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curObj toPath] withParams:[curObj toParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        curObj.isLoading = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"发布管理_列表"];
            
            id resultData = [data valueForKeyPath:@"data"];
            EACodeReleases *resultA = [NSObject objectOfClass:@"EACodeReleases" fromJSON:resultData];
            if (curObj.curPro) {
                [resultA.list setValue:curObj.curPro forKey:@"project"];
            }
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_CodeRelease_WithObj:(EACodeRelease *)curObj andBlock:(void (^)(EACodeRelease *data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/git/releases/tag/%@", curObj.project.owner_user_name, curObj.project.name, curObj.tag_name];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"发布管理_详情"];
            
            id resultData = [data valueForKeyPath:@"data"];
            EACodeRelease *resultA = [NSObject objectOfClass:@"EACodeRelease" fromJSON:resultData];
            resultA.project = curObj.project;
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_DeleteCodeRelease:(EACodeRelease *)curObj andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/git/releases/delete/%@", curObj.project.owner_user_name, curObj.project.name, curObj.tag_name];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"发布管理_删除"];
        }
        block(data, error);
    }];
}

- (void)request_ModifyCodeRelease:(EACodeRelease *)curObj andBlock:(void (^)(EACodeRelease *data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:curObj.editPath withParams:curObj.editParams withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"发布管理_删除"];
            
            id resultData = [data valueForKeyPath:@"data"];
            EACodeRelease *resultA = [NSObject objectOfClass:@"EACodeRelease" fromJSON:resultData];
            resultA.project = curObj.project;
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

#pragma mark Wiki
- (void)request_WikiListWithPro:(Project *)pro andBlock:(void (^)(id data, NSError *error))block{
    
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/wikis", pro.owner_user_name, pro.name];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"Wiki_列表"];
            
            data = [NSObject arrayFromJSON:data[@"data"] ofObjects:@"EAWiki"];
        }
        block(data, error);
    }];
}

- (void)request_WikiDetailWithPro:(Project *)pro iid:(NSNumber *)iid version:(NSNumber *)version andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/wiki/%@", pro.owner_user_name, pro.name, iid];
    NSMutableDictionary *params = @{}.mutableCopy;
    params[@"version"] = version;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"Wiki_详情"];
            
            data = [NSObject objectOfClass:@"EAWiki" fromJSON:data[@"data"]];
        }
        block(data, error);
    }];
}
- (void)request_DeleteWikiWithPro:(Project *)pro iid:(NSNumber *)iid andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/wiki/%@", pro.owner_user_name, pro.name, iid];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"Wiki_删除"];
        }
        block(data, error);
    }];
}

- (void)request_ModifyWiki:(EAWiki *)wiki pro:(Project *)pro andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/wiki", pro.owner_user_name, pro.name];
    NSMutableDictionary *params = @{}.mutableCopy;
    params[@"iid"] = wiki.iid;
    params[@"parentIid"] = wiki.parentIid;
    params[@"order"] = wiki.order;
    params[@"msg"] = @"Modified By App";
    params[@"title"] = wiki.mdTitle;
    params[@"content"] = wiki.mdContent;
    
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"Wiki_修改"];
            
            data = [NSObject objectOfClass:@"EAWiki" fromJSON:data[@"data"]];
        }
        block(data, error);
    }];
}

- (void)request_WikiHistoryWithWiki:(EAWiki *)wiki pro:(Project *)pro andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/wiki/%@/histories", pro.owner_user_name, pro.name, wiki.iid];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"Wiki_历史版本"];
            
            data = [NSObject arrayFromJSON:data[@"data"] ofObjects:@"EAWiki"];
        }
        block(data, error);
    }];
}

- (void)request_RevertWiki:(NSNumber *)wikiIid toVersion:(NSNumber *)version pro:(Project *)pro andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/wiki/%@/history", pro.owner_user_name, pro.name, wikiIid];
    NSMutableDictionary *params = @{}.mutableCopy;
    params[@"version"] = version;
    
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"Wiki_恢复"];
            
            data = [NSObject objectOfClass:@"EAWiki" fromJSON:data[@"data"]];
        }
        block(data, error);
    }];
}

#pragma mark Task
- (void)request_AddTask:(Task *)task andBlock:(void (^)(id data, NSError *error))block{
    [NSObject showStatusBarQueryStr:@"正在添加任务"];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[task toAddTaskPath] withParams:[task toAddTaskParams] withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"任务_添加"];

            id resultData = [data valueForKeyPath:@"data"];
            Task *resultT = [NSObject objectOfClass:@"Task" fromJSON:resultData];
            [NSObject showStatusBarSuccessStr:@"添加任务成功"];
            block(resultT, nil);
        }else{
            [NSObject showStatusBarError:error];
            block(nil, error);
        }
    }];
}
- (void)request_DeleteTask:(Task *)task andBlock:(void (^)(id data, NSError *error))block{
    [NSObject showStatusBarQueryStr:@"正在删除任务"];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[task toDeleteTaskPath] withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"任务_删除"];

            [NSObject showStatusBarSuccessStr:@"删除任务成功"];
            block(task, nil);
        }else{
            [NSObject showStatusBarError:error];
            block(nil, error);
        }
    }];
}
- (void)request_EditTask:(Task *)task oldTask:(Task *)oldTask andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[task toUpdatePath] withParams:[task toUpdateParamsWithOld:oldTask] withMethodType:Put andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"任务_修改"];

            block(task, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_EditTask:(Task *)task withDescriptionStr:(NSString *)descriptionStr andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[task toUpdateDescriptionPath] withParams:@{@"description" : descriptionStr} withMethodType:Put andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"任务_修改描述"];

            data = [data valueForKey:@"data"];
            Task_Description *taskD = [NSObject objectOfClass:@"Task_Description" fromJSON:data];
            block(taskD, nil);
        }else{
            block(nil, error);
        }
    }];
    
}

- (void)request_EditTask:(Task *)task withTags:(NSMutableArray *)selectedTags andBlock:(void (^)(id data, NSError *error))block{
    NSDictionary *params = @{@"label_id" : [selectedTags valueForKey:@"id"]};
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[task toEditLabelsPath] withParams:params withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"任务_修改标签"];

            block(data, nil);
        }else{
            block(nil,error);
        }
    }];
}

- (void)request_ChangeTaskStatus:(Task *)task andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[task toEditTaskStatusPath] withParams:[task toChangeStatusParams] withMethodType:Put andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"任务_完成or开启"];

            task.status = [NSNumber numberWithInteger:(task.status.integerValue != 1? 1 : 2)];
            block(task, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_TaskDetail:(Task *)task andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[task toTaskDetailPath] withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {//请求任务基本内容
        if (data) {
            id resultData = [data valueForKeyPath:@"data"];
            Task *resultA = [NSObject objectOfClass:@"Task" fromJSON:resultData];
            [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[resultA toWatchersPath] withParams:@{@"pageSize": @1000} withMethodType:Get andBlock:^(id dataW, NSError *errorW) {//请求任务关注者
                if (dataW) {
                    dataW = dataW[@"data"][@"list"];
                    NSArray *watchers = [NSObject arrayFromJSON:dataW ofObjects:@"User"];
                    resultA.watchers = watchers.mutableCopy;
                    
                    if (resultA.has_description.boolValue) {
                        [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[resultA toDescriptionPath] withParams:nil withMethodType:Get andBlock:^(id dataD, NSError *errorD) {//请求任务描述
                            if (dataD) {
                                [MobClick event:kUmeng_Event_Request_Get label:@"任务_详情_有描述"];

                                dataD = [dataD valueForKey:@"data"];
                                Task_Description *taskD = [NSObject objectOfClass:@"Task_Description" fromJSON:dataD];
                                resultA.task_description = taskD;
                                block(resultA, nil);
                            }else{
                                block(nil, errorD);
                            }
                        }];
                    }else{
                        [MobClick event:kUmeng_Event_Request_Get label:@"任务_详情_无描述"];
                        
                        block(resultA, nil);
                    }
                }else{
                    block(nil, errorW);
                }
            }];
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_TaskResourceReference:(Task *)task andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[task toResourceReferencePath] withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"任务_关联资源"];

            ResourceReference *rr = [NSObject objectOfClass:@"ResourceReference" fromJSON:data[@"data"]];
            block(rr, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_DeleteResourceReference:(NSNumber *)iid ofTask:(Task *)task andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[task toResourceReferencePath] withParams:@{@"iid": iid} withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"任务_关联资源_删除"];
        }
        block(data, error);
    }];
}

- (void)request_DeleteResourceReference:(NSNumber *)iid ResourceReferencePath:(NSString *)ResourceReferencePath andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:ResourceReferencePath withParams:@{@"iid": iid} withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"任务_关联资源_删除"];
        }
        block(data, error);
    }];
}

- (void)request_ActivityListOfTask:(Task *)task andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[task toActivityListPath] withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"任务_动态列表"];

            id resultData = [data valueForKeyPath:@"data"];
            NSMutableArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"ProjectActivity"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_DoCommentToTask:(Task *)task andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[task toDoCommentPath] withParams:[task toDoCommentParams] withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"任务_评论_添加"];

            id resultData = [data valueForKeyPath:@"data"];
            TaskComment *resultA = [NSObject objectOfClass:@"TaskComment" fromJSON:resultData];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_DeleteComment:(TaskComment *)comment ofTask:(Task *)task andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[NSString stringWithFormat:@"api/task/%ld/comment/%ld", (long)task.id.integerValue, (long)comment.id.integerValue] withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"任务_评论_删除"];

            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_ChangeWatcher:(User *)watcher ofTask:(Task *)task andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/task/%@/user/%@/watch", task.id.stringValue, watcher.global_key];
    User *hasWatcher = [task hasWatcher:watcher];
    NetworkMethod method = hasWatcher? Delete: Post;

    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:method andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:method == Post? @"任务_添加关注者": @"任务_删除关注者"];
            
            if (!hasWatcher && watcher) {
                [task.watchers addObject:watcher];
            }else if (hasWatcher){
                [task.watchers removeObject:hasWatcher];
            }
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_projects_tasks_labelsWithRole:(TaskRoleType)role projectId:(NSString *)projectId andBlock:(void (^)(id data, NSError *error))block {
    NSString *roleStr;
    NSDictionary *param;
    NSArray *roleArray = @[@"owner", @"watcher", @"creator"];
    if (role < roleArray.count) {
        roleStr = roleArray[role];
    }
    
    if (roleStr != nil) {
        param = @{@"role": roleStr};
    }

    NSString *urlStr;
    if (projectId == nil) {
        urlStr = @"api/projects/tasks/labels";
    } else {
        urlStr = [NSString stringWithFormat:@"api/project/%@/tasks/labels", projectId];
    }
    
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:urlStr withParams:param withMethodType:Get andBlock:^(id data, NSError *error) {
        NSArray *dataArray = data[@"data"];
        NSMutableDictionary *pinyinDict = @{}.mutableCopy;
        for (NSDictionary *dict in dataArray) {
            NSString *pinyinName = dict[@"name"];
            pinyinName = [pinyinName stringByReplacingOccurrencesOfString:@"呵" withString:@"HE"];//一个多音字的..唉
            pinyinName = [pinyinName transformToPinyin];
            [pinyinDict setObject:dict forKey:pinyinName];
        }
        
        NSArray *nameSortArray = [[pinyinDict allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        
        NSMutableArray *newPinyinData = @[].mutableCopy;
        for (NSString *pinyinName in nameSortArray) {
            [newPinyinData addObject:pinyinDict[pinyinName]];
        }
        
        if (data) {
            block(newPinyinData, nil);
        }else{
            block(nil, error);
        }
    }];

}

- (void)request_tasks_searchWithUserId:(NSString *)userId role:(TaskRoleType )role project_id:(NSString *)project_id keyword:(NSString *)keyword status:(NSString *)status label:(NSString *)label page:(NSInteger)page andBlock:(void (^)(id data, NSError *error))block {
    NSMutableDictionary *param = @{@"page": @(page)}.mutableCopy;
    if (userId != nil) {
        [param setValue:userId forKey:@"owner"];
    }
    if (project_id != nil && project_id.integerValue >= 0) {
        [param setValue:project_id forKey:@"project_id"];
    }
    if (keyword != nil) {
        [param setValue:keyword forKey:@"keyword"];
    }
    if (status != nil) {
        [param setValue:status forKey:@"status"];
    }
    if (label != nil) {
        [param setValue:label forKey:@"label"];
    }
    
    NSArray *roleArray = @[@"owner", @"watcher", @"creator"];
    if (role < roleArray.count) {
        [param setValue:[Login curLoginUser].id.stringValue forKey:roleArray[role]];

    }
    
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/tasks/search" withParams:param withMethodType:Get andBlock:^(id data, NSError *error) {
        
        Tasks *pros = [NSObject objectOfClass:@"Tasks" fromJSON:data[@"data"]];
        pros.list = [NSObject arrayFromJSON:data[@"data"][@"list"] ofObjects:@"Task"];
        if (status.integerValue == 1) {
            pros.processingList = pros.list;
        } else if (status.integerValue == 2) {
            pros.doneList = pros.list;
        }
 
        if (data) {
            block(pros, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_project_tasks_countWithProjectId:(NSString *)projectId andBlock:(void (^)(id data, NSError *error))block {
    
    NSString *urlStr;
    if (projectId == nil) {
        urlStr = @"api/tasks/count";
    } else {
        urlStr = [NSString stringWithFormat:@"api/project/%@/tasks/counts", projectId];
    }
    
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:urlStr withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_project_task_countWithProjectId:(NSString *)projectId andBlock:(void (^)(id data, NSError *error))block {
    
    NSString *urlStr;
    if (projectId == nil) {
        urlStr = @"api/tasks/count";
    } else {
        urlStr = [NSString stringWithFormat:@"api/project/%@/task/count", projectId];
    }
    
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:urlStr withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_project_user_tasks_countsWithProjectId:(NSString *)projectId memberId:(NSString *)memberId andBlock:(void (^)(id data, NSError *error))block {
    
    NSString *urlStr;
    if (memberId == nil) {
        urlStr = @"api/tasks/search";
    } else {
        urlStr = [NSString stringWithFormat:@"api/project/%@/user/%@/tasks/counts", projectId, memberId];
    }
    
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:urlStr withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_tasks_searchWithUserId:(NSString *)userId role:(TaskRoleType )role project_id:(NSString *)project_id andBlock:(void (^)(id data, NSError *error))block {
    
    NSString *urlStr;
    NSDictionary *param;
    if (userId == nil) { //无成员时
        if (role == TaskRoleTypeWatcher || role == TaskRoleTypeCreator) { //创建和关注
            urlStr = [NSString stringWithFormat:@"api/project/%@/tasks/counts", project_id];
        } else { //全部任务
            urlStr = [NSString stringWithFormat:@"api/project/%@/task/count", project_id];
        }
    } else { //有成员时
        urlStr = [NSString stringWithFormat:@"api/project/%@/user/%@/tasks/counts", project_id, userId];

    }
    
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:urlStr withParams:param withMethodType:Get andBlock:^(id data, NSError *error) {
        
        if (data) {
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_projects_tasks_labelsWithRole:(TaskRoleType)role projectId:(NSString *)projectId projectName:(NSString *)projectName memberId:(NSString *)memberId owner_user_name:(NSString *)owner_user_name andBlock:(void (^)(id data, NSError *error))block {
    NSDictionary *param;
    NSArray *roleArray = @[@"owner", @"watcher", @"creator"];
    if (role < roleArray.count) {
        param = @{@"role": roleArray[role]};
    }
    NSString *urlStr;
    if (projectId != nil && memberId != nil) { //有成员
         urlStr = [NSString stringWithFormat:@"api/project/%@/user/%@/tasks/labels", projectId, memberId];
        
    } else {
        if (role == TaskRoleTypeWatcher || role == TaskRoleTypeCreator) {
            urlStr = [NSString stringWithFormat:@"api/project/%@/tasks/labels", projectId];

        } else {
            urlStr = [NSString stringWithFormat:@"api/user/%@/project/%@/task/label?withCount=true", owner_user_name, projectName];
        }
    }
    
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:urlStr withParams:param withMethodType:Get andBlock:^(id data, NSError *error) {
        NSArray *dataArray = data[@"data"];
        NSMutableDictionary *pinyinDict = @{}.mutableCopy;
        for (NSDictionary *dict in dataArray) {
            NSString *pinyinName = [dict[@"name"] transformToPinyin];
            [pinyinDict setObject:dict forKey:pinyinName];
        }
        
        NSArray *nameSortArray = [[pinyinDict allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        
        NSMutableArray *newPinyinData = @[].mutableCopy;
        for (NSString *pinyinName in nameSortArray) {
            [newPinyinData addObject:pinyinDict[pinyinName]];
        }
        
        if (data) {
            block(newPinyinData, nil);
        }else{
            block(nil, error);
        }
    }];
    
}

#pragma mark - TaskBoard
- (void)request_BoardTaskListsInPro:(Project *)pro andBlock:(void (^)(NSArray<EABoardTaskList *> *data, NSError *error))block{
//    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/tasks/board/list", pro.owner_user_name, pro.name];
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/tasks/board", pro.owner_user_name, pro.name];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:@{@"pageSize": @999} withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"看板列表"];
            
//            NSArray<EABoardTaskList *> *resultA = [NSObject arrayFromJSON:data[@"data"][@"list"] ofObjects:@"EABoardTaskList"];
            NSArray<EABoardTaskList *> *resultA = [NSObject arrayFromJSON:data[@"data"][@"board_lists"] ofObjects:@"EABoardTaskList"];
            if (resultA) {
                if (resultA.count > 2) {
                    pro.hasEverHandledBoard = YES;
                }
                pro.board_id = resultA.firstObject.board_id;
                [resultA setValue:pro forKey:@"curPro"];//辅助属性
            }
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_AddBoardTaskListsInPro:(Project *)pro withTitle:(NSString *)title andBlock:(void (^)(EABoardTaskList *data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/tasks/board/%@/list", pro.owner_user_name, pro.name, pro.board_id];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:@{@"title": title ?: @""} withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"看板列表_添加"];
            
            data = [NSObject objectOfClass:@"EABoardTaskList" fromJSON:data[@"data"]];
        }
        block(data, error);
    }];
}

- (void)request_DeleteBoardTaskList:(EABoardTaskList *)boardTL andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/tasks/board/%@/list/%@", boardTL.curPro.owner_user_name, boardTL.curPro.name, boardTL.board_id, boardTL.id];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"看板列表_删除"];
        }
        block(data, error);
    }];

}

- (void)request_RenameBoardTaskList:(EABoardTaskList *)boardTL withTitle:(NSString *)title andBlock:(void (^)(EABoardTaskList *data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/tasks/board/%@/list/%@", boardTL.curPro.owner_user_name, boardTL.curPro.name, boardTL.board_id, boardTL.id];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:@{@"title": title ?: @""} withMethodType:Put andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"看板列表_修改"];
            
            data = [NSObject objectOfClass:@"EABoardTaskList" fromJSON:data[@"data"]];
        }
        block(data, error);
    }];
}

- (void)request_TaskInBoardTaskList:(EABoardTaskList *)boardTL andBlock:(void (^)(EABoardTaskList *data, NSError *error))block{//这里返回的 data 主要是 list 和 page 数据，而没有 EABoardTaskList 的相关业务属性
    boardTL.isLoading = YES;
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/tasks/board/%@/list/%@/tasks", boardTL.curPro.owner_user_name, boardTL.curPro.name, boardTL.board_id, boardTL.id];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:boardTL.toParams withMethodType:Get andBlock:^(id data, NSError *error) {
        boardTL.isLoading = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"看板列表_任务列表"];
            
            data = [NSObject objectOfClass:@"EABoardTaskList" fromJSON:data[@"data"]];
        }
        block(data, error);
    }];
}

- (void)request_PutTask:(Task *)task toBoardTaskList:(EABoardTaskList *)boardTL andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/tasks/board/%@/list/%@/task/%@", task.project.owner_user_name, task.project.name, boardTL.board_id, boardTL.id, task.id];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Put andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"任务_修改看板列表"];
        }
        block(data, error);
    }];
}

#pragma mark User
- (void)request_AddUser:(User *)user ToProject:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
//    一次添加多个成员(逗号分隔)：users=102,4 (以后只支持 gk，不支持 id 了)
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[NSString stringWithFormat:@"api/project/%ld/members/gk/add", project.id.longValue] withParams:@{@"users" : user.global_key} withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"项目_添加成员"];

            id resultData = [data valueForKeyPath:@"data"];
            block(resultData, nil);
        }else{
            block(nil, error);
        }
    }];
}

#pragma mark Topic
- (void)request_ProjectTopicList_WithObj:(ProjectTopics *)proTopics andBlock:(void (^)(id data, NSError *error))block{
    proTopics.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[proTopics toRequestPath] withParams:[proTopics toParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        proTopics.isLoading = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"讨论列表"];

            id resultData = [data valueForKeyPath:@"data"];
            ProjectTopics *resultT = [NSObject objectOfClass:@"ProjectTopics" fromJSON:resultData];
            block(resultT, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_ProjectTopic_WithObj:(ProjectTopic *)proTopic andBlock:(void (^)(id data, NSError *error))block{
    proTopic.isTopicLoading = YES;
    //html详情
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[proTopic toTopicPath] withParams:@{@"type": [NSNumber numberWithInteger:0]} withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            //markdown详情
            id resultData = [data valueForKeyPath:@"data"];
            ProjectTopic *resultT = [NSObject objectOfClass:@"ProjectTopic" fromJSON:resultData];
            resultT.mdLabels = [resultT.labels mutableCopy];
            [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[proTopic toTopicPath] withParams:@{@"type": [NSNumber numberWithInteger:1]} withMethodType:Get andBlock:^(id dataMD, NSError *errorMD) {
                if (dataMD) {
                    resultT.mdTitle = [[dataMD valueForKey:@"data"] valueForKey:@"title"];
                    resultT.mdContent = [[dataMD valueForKey:@"data"] valueForKey:@"content"];
                    NSString *watchersPath = [NSString stringWithFormat:@"api/project/%@/topic/%@/watchers", resultT.project_id.stringValue, resultT.id.stringValue];
                    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:watchersPath withParams:@{@"pageSize": @1000} withMethodType:Get andBlock:^(id dataW, NSError *errorW) {
                        proTopic.isTopicLoading = NO;
                        if (dataW) {
                            [MobClick event:kUmeng_Event_Request_Get label:@"讨论详情"];

                            NSArray *watchers = [NSArray arrayFromJSON:dataW[@"data"][@"list"] ofObjects:@"User"];
                            resultT.watchers = watchers.mutableCopy;
                            block(resultT, nil);
                        }else{
                            block(nil, errorW);
                        }
                    }];
                }else{
                    block(nil, errorMD);
                }
            }];
        } else {
            proTopic.isTopicLoading = NO;
            block(nil, error);
        }
    }];
}
- (void)request_ModifyProjectTpoicLabel:(ProjectTopic *)proTopic andBlock:(void (^)(id data, NSError *error))block
{
    proTopic.isTopicEditLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[proTopic toLabelPath]
                                                        withParams:[proTopic toLabelParams]
                                                    withMethodType:Post
                                                          andBlock:^(id data, NSError *error) {
        proTopic.isTopicEditLoading = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"讨论_标签_修改"];
            
            block(data, nil);
        } else {
            block(nil, error);
        }
    }];
}
- (void)request_ModifyProjectTpoic:(ProjectTopic *)proTopic andBlock:(void (^)(id data, NSError *error))block
{
    proTopic.isTopicEditLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[proTopic toTopicPath] withParams:[proTopic toEditParams] withMethodType:Put andBlock:^(id data, NSError *error) {
        proTopic.isTopicEditLoading = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"讨论_编辑"];

            id resultData = [data valueForKeyPath:@"data"];
            ProjectTopic *resultT = [NSObject objectOfClass:@"ProjectTopic" fromJSON:resultData];
            block(resultT, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_AddProjectTpoic:(ProjectTopic *)proTopic andBlock:(void (^)(id data, NSError *error))block{
    NSInteger feedbackId = 38894;
    [NSObject showStatusBarQueryStr:(proTopic.project_id && proTopic.project_id.integerValue == feedbackId)? @"正在发送反馈信息": @"正在添加讨论"];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[proTopic toAddTopicPath] withParams:[proTopic toAddTopicParams] withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:(proTopic.project_id && proTopic.project_id.integerValue == feedbackId)? @"发送反馈" : @"讨论_添加"];

            [NSObject showStatusBarSuccessStr:(proTopic.project_id && proTopic.project_id.integerValue == feedbackId)? @"反馈成功": @"添加讨论成功"];
            id resultData = [data valueForKeyPath:@"data"];
            ProjectTopic *resultT = [NSObject objectOfClass:@"ProjectTopic" fromJSON:resultData];
            block(resultT, nil);
        }else{
            [NSObject showStatusBarError:error];
            block(nil, error);
        }
    }];
}

- (void)request_Comments_WithProjectTpoic:(ProjectTopic *)proTopic andBlock:(void (^)(id data, NSError *error))block{
    proTopic.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[proTopic toCommentsPath] withParams:[proTopic toCommentsParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        proTopic.isLoading = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"讨论_评论列表"];

            id resultData = [data valueForKeyPath:@"data"];
            ProjectTopics *resultT = [NSObject objectOfClass:@"ProjectTopics" fromJSON:resultData];
            block(resultT, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_Comments_WithAnswer:(ProjectTopic *)proTopic inProjectId:(NSNumber *)projectId andBlock:(void (^)(id data, NSError *error))block{
    proTopic.isLoading = YES;
    NSString *path = [NSString stringWithFormat:@"api/project/%@/topic/%@/comment/%@/comments", projectId, proTopic.parent_id, proTopic.id];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:@{@"pageSize": @(99999)} withMethodType:Get andBlock:^(id data, NSError *error) {
        proTopic.isLoading = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"讨论_答案_评论列表"];
            
            id resultData = [data valueForKeyPath:@"data"];
            ProjectTopics *resultT = [NSObject objectOfClass:@"ProjectTopics" fromJSON:resultData];
            block(resultT, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_UpvoteAnswer:(ProjectTopic *)proTopic inProjectId:(NSNumber *)projectId andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/project/%@/topic/%@/comment/%@/upvote", projectId, proTopic.parent_id, proTopic.id];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:proTopic.is_up_voted.boolValue? Delete: Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"讨论_答案_点赞"];
            
            [proTopic change_is_up_voted];
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];

}
- (void)request_DoComment_WithProjectTpoic:(ProjectTopic *)proTopic andAnswerId:(NSNumber *)answerId andBlock:(void (^)(id data, NSError *error))block{
    NSMutableDictionary *params = @{@"content" : [proTopic.nextCommentStr aliasedString]}.mutableCopy;
    params[@"type"] = answerId? @1: @0;
    params[@"parent_id"] = answerId;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[proTopic toDoCommentPath] withParams:params withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"讨论_评论_添加"];

            id resultData = [data valueForKeyPath:@"data"];
            ProjectTopic *resultT = [NSObject objectOfClass:@"ProjectTopic" fromJSON:resultData];
            block(resultT, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_ProjectTopic_Delete_WithObj:(ProjectTopic *)proTopic andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[proTopic toDeletePath] withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"讨论_删除"];

            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_ProjectTopicComment_Delete_WithObj:(ProjectTopic *)proTopic projectId:(NSNumber *)projectId andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/project/%@/topic/%@/comment/%@", projectId, proTopic.topic_id, proTopic.id];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"讨论评论_删除"];
            
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_ChangeWatcher:(User *)watcher ofTopic:(ProjectTopic *)proTopic andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/topic/%@/user/%@/watch", proTopic.id.stringValue, watcher.global_key];
    User *hasWatcher = [proTopic hasWatcher:watcher];
    NetworkMethod method = hasWatcher? Delete: Post;
    
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:method andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:method == Post? @"讨论_添加关注者": @"讨论_删除关注者"];
            
            if (!hasWatcher && watcher) {
                [proTopic.watchers addObject:watcher];
            }else if (hasWatcher){
                [proTopic.watchers removeObject:hasWatcher];
            }
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];

}

- (void)request_ProjectTopic_Count_WithPath:(NSString *)path
                                   andBlock:(void (^)(id data, NSError *error))block
{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path
                                                        withParams:nil
                                                    withMethodType:Get
                                                          andBlock:^(id data, NSError *error) {
                                                              if (data) {
                                                                  [MobClick event:kUmeng_Event_Request_Get label:@"讨论_数量"];

                                                                  id resultData = [data valueForKeyPath:@"data"];
                                                                  block(resultData, nil);
                                                              } else {
                                                                  block(nil, error);
                                                              }
                                                          }];
}
- (void)request_ProjectTopic_LabelMy_WithPath:(NSString *)path
                                     andBlock:(void (^)(id data, NSError *error))block
{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path
                                                        withParams:nil
                                                    withMethodType:Get
                                                          andBlock:^(id data, NSError *error) {
                                                              if (data) {
                                                                  [MobClick event:kUmeng_Event_Request_Get label:@"讨论_标签列表_与我相关"];

                                                                  id resultData = [data valueForKeyPath:@"data"];
                                                                  NSArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"ProjectTag"];
                                                                  block(resultA, nil);
                                                              } else {
                                                                  block(nil, error);
                                                              }
                                                          }];
}

#pragma mark - Project Tag
- (void)request_TagListInProject:(Project *)project type:(ProjectTagType)type andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = nil;
    switch (type) {
        case ProjectTagTypeTopic:
            path = [NSString stringWithFormat:@"api/project/%@/topic/label?withCount=true", project.id.stringValue];
            break;
            case ProjectTagTypeTask:
            path = [NSString stringWithFormat:@"api/user/%@/project/%@/task/label?withCount=true", project.owner_user_name, project.name];
            break;
        default:
            return;
            break;
    }
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"标签列表"];

            id resultData = [data valueForKeyPath:@"data"];
            NSArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"ProjectTag"];
            block(resultA, nil);
        } else {
            block(nil, error);
        }
    }];

}
- (void)request_AddTag:(ProjectTag *)tag toProject:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/topics/label", project.owner_user_name, project.name];
    NSDictionary *params = @{@"name" : tag.name,
                             @"color" : tag.color};
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"标签_添加"];

            block(data[@"data"], nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_DeleteTag:(ProjectTag *)tag inProject:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/topics/label/%@", project.owner_user_name, project.name, tag.id.stringValue];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"标签_删除"];

            block(data, nil);
        } else {
            block(nil, error);
        }
    }];
}
- (void)request_ModifyTag:(ProjectTag *)tag inProject:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/topics/label/%@", project.owner_user_name, project.name, tag.id.stringValue];
    NSDictionary *params = @{@"name" : tag.name,
                             @"color" : tag.color};
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Put andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"标签_修改"];

            block(data, nil);
        } else {
            block(nil, error);
        }
    }];

}

#pragma mark Tweet
- (void)request_Tweets_WithObj:(Tweets *)tweets andBlock:(void (^)(id data, NSError *error))block{
    tweets.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[tweets toPath] withParams:[tweets toParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        tweets.isLoading = NO;
        
        if (data) {
            [MobClick event:kUmeng_Event_Request_RootList label:@"冒泡_列表"];
            id resultData = [data valueForKeyPath:@"data"];
            NSArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"Tweet"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_Tweet_DoLike_WithObj:(Tweet *)tweet andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[tweet toDoLikePath] withParams:nil withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"冒泡_点赞"];

            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_Tweet_DoComment_WithObj:(Tweet *)tweet andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[tweet toDoCommentPath] withParams:[tweet toDoCommentParams] withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"冒泡_评论_添加"];

            id resultData = [data valueForKeyPath:@"data"];
            Comment *comment = [NSObject objectOfClass:@"Comment" fromJSON:resultData];
            block(comment, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_Tweet_DoTweet_WithObj:(Tweet *)tweet andBlock:(void (^)(id data, NSError *error))block{
    //发送冒泡内容 block
    void (^sendTweetBlock)() = ^{
        [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/tweet" withParams:[tweet toDoTweetParams] withMethodType:Post andBlock:^(id data, NSError *error) {
            if (data) {
                [MobClick event:kUmeng_Event_Request_ActionOfServer label:tweet.tweetImages.count > 0? @"冒泡_添加_有图": @"冒泡_添加_无图"];
                
                id resultData = [data valueForKeyPath:@"data"];
                Tweet *result = [NSObject objectOfClass:@"Tweet" fromJSON:resultData];
                [NSObject showStatusBarSuccessStr:@"冒泡发送成功"];
                block(result, nil);
            }else{
                [NSObject showStatusBarError:error];
                block(nil, error);
            }
        }];
    };
    //开始发送
    [NSObject showStatusBarQueryStr:@"正在发送冒泡"];
    //无图片的冒泡，直接发送
    if (tweet.tweetImages.count <= 0) {
        sendTweetBlock();
        return;
    }
    //判断图片是否全部上传完毕，是的话就发送该冒泡 block
    BOOL (^whetherAllImagesUploadedAndSendTweetBlock)() = ^{
        if (tweet.isAllImagesDoneSucess) {
            sendTweetBlock();
        }
        return tweet.isAllImagesDoneSucess;
    };
    //图片均已上传，直接发送
    if (whetherAllImagesUploadedAndSendTweetBlock()) {
        return;
    }
    //遍历上传图片
    for (TweetImage *imageItem in tweet.tweetImages) {
        if (imageItem.imageStr.length > 0) {
            whetherAllImagesUploadedAndSendTweetBlock();
        }else{
            if (imageItem.uploadState != TweetImageUploadStateIng) {
                imageItem.uploadState = TweetImageUploadStateIng;
                [self uploadTweetImage:imageItem.image doneBlock:^(NSString *imagePath, NSError *error) {
                    imageItem.uploadState = imagePath? TweetImageUploadStateSuccess: TweetImageUploadStateFail;
                    if (!imagePath) {
                        [NSObject showStatusBarError:error];
                        block(nil, error);
                    }else{
                        imageItem.imageStr = [NSString stringWithFormat:@"![](%@)", imagePath];
                        whetherAllImagesUploadedAndSendTweetBlock();
                    }
                } progerssBlock:^(CGFloat progressValue) {
                    DebugLog(@"progressValue %@ : %.2f", imageItem.assetLocalIdentifier, progressValue);
                }];
            }
        }
    }
}

- (void)request_Tweet_DoProjectTweet_WithPro:(NSNumber *)pro_id content:(NSString *)content andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/project/%@/tweet", pro_id.stringValue];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:@{@"content": content} withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"冒泡_添加_项目内冒泡"];
            
            id resultData = [data valueForKeyPath:@"data"];
            Tweet *result = [NSObject objectOfClass:@"Tweet" fromJSON:resultData];
            block(result, nil);
        }else{
            [NSObject showStatusBarError:error];
            block(nil, error);
        }
    }];
}

- (void)request_Tweet_EditProjectTweet:(Tweet *)tweet content:(NSString *)content andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/project/%@/tweet/%@", tweet.project_id, tweet.id];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:@{@"raw": content} withMethodType:Put andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"冒泡_修改_项目内冒泡"];
            
            id resultData = [data valueForKeyPath:@"data"];
            Tweet *result = [NSObject objectOfClass:@"Tweet" fromJSON:resultData];
            block(result, nil);
        }else{
            [NSObject showStatusBarError:error];
            block(nil, error);
        }
    }];
}

- (void)request_Tweet_Likers_WithObj:(Tweet *)tweet andBlock:(void (^)(id data, NSError *error))block{
    tweet.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[tweet toLikersPath] withParams:[tweet toLikersParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        tweet.isLoading = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"冒泡_点赞的人_列表"];

            id resultData = [data valueForKeyPath:@"data"];
            resultData = [resultData valueForKeyPath:@"list"];
            NSArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"User"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_Tweet_LikesAndRewards_WithObj:(Tweet *)tweet andBlock:(void (^)(id data, NSError *error))block{
    tweet.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[tweet toLikesAndRewardsPath] withParams:[tweet toLikesAndRewardsParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        tweet.isLoading = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"冒泡_赞赏的人_列表"];
            
            id resultData = [data valueForKeyPath:@"data"];
            block(resultData, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_Tweet_Comments_WithObj:(Tweet *)tweet andBlock:(void (^)(id data, NSError *error))block{
    tweet.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[tweet toCommentsPath] withParams:[tweet toCommentsParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        tweet.isLoading = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"冒泡_评论_列表"];

            id resultData = [data valueForKeyPath:@"data"];
            if ([resultData isKindOfClass:[NSDictionary class]]) {
                resultData = [resultData valueForKeyPath:@"list"];
            }
            NSArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"Comment"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_Tweet_Delete_WithObj:(Tweet *)tweet andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[tweet toDeletePath] withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"冒泡_删除"];

            [NSObject showHudTipStr:@"删除成功"];
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_TweetComment_Delete_WithTweet:(Tweet *)tweet andComment:(Comment *)comment andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/tweet/%d/comment/%d", tweet.id.intValue, comment.id.intValue];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"冒泡_评论_删除"];

            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_Tweet_Detail_WithObj:(Tweet *)tweet andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[tweet toDetailPath] withParams:@{@"withRaw": @YES} withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"冒泡_详情"];

            id resultData = [data valueForKeyPath:@"data"];
            Tweet *resultA = [NSObject objectOfClass:@"Tweet" fromJSON:resultData];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_PublicTweetsWithTopic:(NSInteger)topicID last_id:(NSNumber *)last_id andBlock:(void (^)(id data, NSError *error))block{
    //TODO psy lastid，是否要做分页
    NSString *path = [NSString stringWithFormat:@"api/public_tweets/topic/%ld",(long)topicID];
    NSMutableDictionary *params = @{
                             @"type" : @"topic",
                             @"sort" : @"new",
                             @"size" : @20,
                             }.mutableCopy;
    params[@"last_id"] = last_id;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"话题_冒泡列表"];
            
            id resultData = [data valueForKeyPath:@"data"];
            NSArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"Tweet"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

#pragma mark User
- (void)request_UserInfo_WithObj:(User *)curUser andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curUser toUserInfoPath] withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_RootList label:@"用户信息"];

            id resultData = [data valueForKeyPath:@"data"];
            User *user = [NSObject objectOfClass:@"User" fromJSON:resultData];
            if (user.id.intValue == [Login curLoginUser].id.intValue) {
                if (user.vip.integerValue == 2) {
                    User *loginU = [Login curLoginUser];
                    if (loginU.vip.integerValue < 2) {
                        [CodingVipTipManager showTip];
                    }
                }
                [Login doLogin:resultData];
            }
            block(user, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_ResetPassword_WithObj:(User *)curUser andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curUser toResetPasswordPath] withParams:[curUser toResetPasswordParams] withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"重置密码"];

            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_FollowersOrFriends_WithObj:(Users *)curUsers andBlock:(void (^)(id data, NSError *error))block{
    curUsers.isLoading = YES;
    NSString *path = [curUsers toPath];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:[curUsers toParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        curUsers.isLoading = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"关注or粉丝列表"];

            id resultData = [data valueForKeyPath:@"data"];
            
            if ([path hasSuffix:@"friends"] && resultData) {//AT某人时的列表数据，要保存在本地
                User *loginUser = [Login curLoginUser];
                if (loginUser) {
                    [NSObject saveResponseData:resultData toPath:[loginUser localFriendsPath]];
                }
            }
            
            //处理数据
            NSObject *resultA = nil;
            if ([path hasSuffix:@"stargazers"] || [path hasSuffix:@"watchers"]) {
                resultA = [NSArray arrayFromJSON:resultData ofObjects:@"User"];
            }else{
                resultA = [NSObject objectOfClass:@"Users" fromJSON:resultData];
            }
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_FollowedOrNot_WithObj:(User *)curUser andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curUser toFllowedOrNotPath] withParams:[curUser toFllowedOrNotParams] withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"关注某人"];

            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_UserJobArrayWithBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/options/jobs" withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"个人信息_职位列表"];

            id resultData = [data valueForKeyPath:@"data"];
            block(resultData, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_UserTagArrayWithBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/tagging/user_tag_list" withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"个人信息_个性标签列表"];

            id resultData = [data valueForKeyPath:@"data"];
            NSArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"Tag"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_UpdateUserInfo_WithObj:(User *)curUser andBlock:(void (^)(id data, NSError *error))block{
    [NSObject showStatusBarQueryStr:@"正在修改个人信息"];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curUser toUpdateInfoPath] withParams:[curUser toUpdateInfoParams] withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"个人信息_修改"];

            [NSObject showStatusBarSuccessStr:@"个人信息修改成功"];
            id resultData = [data valueForKeyPath:@"data"];
            User *user = [NSObject objectOfClass:@"User" fromJSON:resultData];
            if (user) {
                if (user.vip.integerValue == 2) {
                    User *loginU = [Login curLoginUser];
                    if (loginU.vip.integerValue < 2) {
                        [CodingVipTipManager showTip];
                    }
                }
                [Login doLogin:resultData];
            }
            block(user, nil);
        }else{
            [NSObject showStatusBarError:error];
            block(nil, error);
        }
    }];
}

- (void)request_GeneratePhoneCodeToResetPhone:(NSString *)phone phoneCountryCode:(NSString *)phoneCountryCode withCaptcha:(NSString *)captcha block:(void (^)(id data, NSError *error))block{
    NSString *path = @"api/account/phone/change/code";
    NSMutableDictionary *params = @{@"phone": phone,
                             @"phoneCountryCode": phoneCountryCode}.mutableCopy;
    if (captcha.length > 0) {
        params[@"j_captcha"] = captcha;
    }
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Post autoShowError:captcha.length > 0 andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"生成手机验证码_绑定手机号"];
        }else if (captcha.length <= 0 && error && error.userInfo[@"msg"] && ![[error.userInfo[@"msg"] allKeys] containsObject:@"j_captcha_error"]) {
            [NSObject showError:error];
        }
        block(data, error);
    }];
}

- (void)request_PointRecords:(PointRecords *)records andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[records toPath] withParams:[records toParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"码币记录"];

            data = [data valueForKey:@"data"];
            PointRecords *resultA = [NSObject objectOfClass:@"PointRecords" fromJSON:data];
            if (!records.points_left) {
                [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/point/points" withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
                    if (data) {
                        records.points_left = data[@"data"][@"points_left"];
                    }
                    block(resultA, nil);
                }];
            }else{
                block(resultA, nil);
            }
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_RewardToTweet:(NSString *)tweet_id encodedPassword:(NSString *)encodedPassword andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/tweet/%@/app_reward", tweet_id];
    NSDictionary *params = encodedPassword.length > 0? @{@"encodedPassword": encodedPassword}: nil;
    
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Post autoShowError:NO andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"打赏成功"];
        }else{
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"打赏失败"];
        }
        block(data, error);
    }];
}

- (void)request_ServiceInfoBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/user/service_info" withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            data = [NSObject objectOfClass:@"UserServiceInfo" fromJSON:data[@"data"]];
            
            [MobClick event:kUmeng_Event_Request_Get label:@"我_查询项目和团队个数"];
        }
        block(data, error);
    }];
}

#pragma mark Message
- (void)request_PrivateMessages:(PrivateMessages *)priMsgs andBlock:(void (^)(id data, NSError *error))block{
    priMsgs.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[priMsgs toPath] withParams:[priMsgs toParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        priMsgs.isLoading = NO;
        if (data) {
            if (priMsgs.curFriend) {
                [MobClick event:kUmeng_Event_Request_Get label:@"私信_列表"];
            }else{
                [MobClick event:kUmeng_Event_Request_RootList label:@"会话列表"];
            }

            id resultA = [PrivateMessages analyzeResponseData:data];
            block(resultA, nil);
            
            if (priMsgs.curFriend && priMsgs.curFriend.global_key) {//标记为已读
                [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[NSString stringWithFormat:@"api/message/conversations/%@/read", priMsgs.curFriend.global_key] withParams:nil withMethodType:Post autoShowError:NO andBlock:^(id data, NSError *error) {
                    if (data) {
                        [[UnReadManager shareManager] updateUnRead];
                    }
                }];
            }
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_Fresh_PrivateMessages:(PrivateMessages *)priMsgs andBlock:(void (^)(id data, NSError *error))block{
    priMsgs.isPolling = YES;
    __weak PrivateMessages *weakMsgs = priMsgs;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[priMsgs toPollPath] withParams:[priMsgs toPollParams] withMethodType:Get autoShowError:NO andBlock:^(id data, NSError *error) {
        __strong PrivateMessages *strongMsgs = weakMsgs;
        strongMsgs.isPolling = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"私信_轮询"];

            id resultData = [data valueForKeyPath:@"data"];
            NSArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"PrivateMessage"];
            
            {//标记为已读
                NSString *myGK = [Login curLoginUser].global_key;
                [resultA enumerateObjectsUsingBlock:^(PrivateMessage *obj, NSUInteger idx, BOOL *stop) {
                    if (idx == 0) {
                        [priMsgs freshLastId:obj.id];
                    }
                    if (obj.sender.global_key.length > 0 && ![obj.sender.global_key isEqualToString:myGK]) {
                        *stop = YES;
                        [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[NSString stringWithFormat:@"api/message/conversations/%@/read", obj.sender.global_key] withParams:nil withMethodType:Post autoShowError:NO andBlock:^(id data, NSError *error) {
                            DebugLog(@"request_Fresh_PrivateMessages Mark Sucess");
                        }];
                    }
                }];
            }
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_SendPrivateMessage:(PrivateMessage *)nextMsg andBlock:(void (^)(id data, NSError *error))block{
    nextMsg.sendStatus = PrivateMessageStatusSending;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[nextMsg toSendPath] withParams:[nextMsg toSendParams] withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"私信_发送_(有图和无图)"];

            id resultData = [data valueForKeyPath:@"data"];
            PrivateMessage *resultA = [NSObject objectOfClass:@"PrivateMessage" fromJSON:resultData];
            nextMsg.sendStatus = PrivateMessageStatusSendSucess;
            block(resultA, nil);
        }else{
            nextMsg.sendStatus = PrivateMessageStatusSendFail;
            block(nil, error);
        }
    }];
}

- (void)request_SendPrivateMessage:(PrivateMessage *)nextMsg andBlock:(void (^)(id data, NSError *error))block progerssBlock:(void (^)(CGFloat progressValue))progress{
    nextMsg.sendStatus = PrivateMessageStatusSending;
    if (nextMsg.nextImg && (!nextMsg.extra || nextMsg.extra.length <= 0)) {
        [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"私信_发送_有图"];
//        先上传图片
        [self uploadTweetImage:nextMsg.nextImg doneBlock:^(NSString *imagePath, NSError *error) {
            if (imagePath) {
//                上传成功后，发送私信
                nextMsg.extra = imagePath;
                [self request_SendPrivateMessage:nextMsg andBlock:block];
            }else{
                nextMsg.sendStatus = PrivateMessageStatusSendFail;
                block(nil, error);
            }
        } progerssBlock:^(CGFloat progressValue) {
        }];
    } else if (nextMsg.voiceMedia) {
        [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"私信_发送_语音"];
        [[CodingNetAPIClient sharedJsonClient] uploadVoice:nextMsg.voiceMedia.file withPath:@"api/message/send_voice" withParams:[nextMsg toSendParams] andBlock:^(id data, NSError *error) {
            if (data) {
                id resultData = [data valueForKeyPath:@"data"];
                PrivateMessage *result = [NSObject objectOfClass:@"PrivateMessage" fromJSON:resultData];
                nextMsg.sendStatus = PrivateMessageStatusSendSucess;
                block(result, nil);
            }else{
                nextMsg.sendStatus = PrivateMessageStatusSendFail;
                block(nil, error);
            }
        }];
    } else {
//        发送私信
        [self request_SendPrivateMessage:nextMsg andBlock:block];
    }
}

- (void)request_playedPrivateMessage:(PrivateMessage *)pm {
    NSString *path = [NSString stringWithFormat:@"/api/message/conversations/%@/play", pm.id];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Post autoShowError:NO andBlock:^(id data, NSError *error) {
        DebugLog(@"request_playedPrivateMessage Mark Sucess");
    }];
}

- (void)request_CodingTips:(CodingTips *)curTips andBlock:(void (^)(id data, NSError *error))block{
    curTips.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curTips toTipsPath] withParams:[curTips toTipsParams] withMethodType:Get andBlock:^(id data, NSError *error) {
        curTips.isLoading = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"消息通知_列表"];

            id resultData = [data valueForKeyPath:@"data"];
            CodingTips *resultA = [NSObject objectOfClass:@"CodingTips" fromJSON:resultData];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_markReadWithCodingTips:(CodingTips *)curTips andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/notification/mark-read" withParams:[curTips toMarkReadParams] withMethodType:Post andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"消息通知_标记某类型全部为已读"];

            block(data, nil);
            [[UnReadManager shareManager] updateUnRead];
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_markReadWithCodingTipIdStr:(NSString *)tipIdStr andBlock:(void (^)(id data, NSError *error))block{
    if (tipIdStr.length <= 0) {
        return;
    }
    NSDictionary *params = @{@"id" : tipIdStr};
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/notification/mark-read" withParams:params withMethodType:Post autoShowError:NO andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"消息通知_标记某条消息为已读"];

            block(data, nil);
            [[UnReadManager shareManager] updateUnRead];
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_DeletePrivateMessage:(PrivateMessage *)curMsg andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curMsg toDeletePath] withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"私信_删除"];

            block(curMsg, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_DeletePrivateMessagesWithObj:(PrivateMessage *)curObj andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[curObj.friend toDeleteConversationPath] withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"会话_删除"];

            block(curObj, nil);
        }else{
            block(nil, error);
        }
    }];
}

#pragma mark Git Related
- (void)request_StarProject:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/%@", project.owner_user_name, project.name, project.stared.boolValue? @"unstar": @"star"];
    project.isStaring = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Post andBlock:^(id data, NSError *error) {
        project.isStaring = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"项目_收藏"];

            project.stared = [NSNumber numberWithBool:!project.stared.boolValue];
            project.star_count = [NSNumber numberWithInteger:project.star_count.integerValue + (project.stared.boolValue? 1: -1)];
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_WatchProject:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/%@", project.owner_user_name, project.name, project.watched.boolValue? @"unwatch": @"watch"];
    project.isWatching = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Post andBlock:^(id data, NSError *error) {
        project.isWatching = NO;
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"项目_关注"];

            project.watched = [NSNumber numberWithBool:!project.watched.boolValue];
            project.watch_count = [NSNumber numberWithInteger:project.watch_count.integerValue + (project.watched.boolValue? 1: -1)];
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}
- (void)request_ForkProject:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/git/fork", project.owner_user_name, project.name];
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:kKeyWindow animated:YES];
    hud.removeFromSuperViewOnHide = YES;
    hud.labelText = @"正在Fork项目";
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Post andBlock:^(id data, NSError *error) {
//        此处得到的 data 是一个GitPro，需要在请求一次Pro的详细信息
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"项目_Fork"];

            project.forked = [NSNumber numberWithBool:!project.forked.boolValue];
            project.fork_count = [NSNumber numberWithInteger:project.fork_count.integerValue +1];
            
            Project *forkedPro = [[Project alloc] init];
            forkedPro.owner_user_name = [Login curLoginUser].global_key;
            forkedPro.name = project.name;
            [[Coding_NetAPIManager sharedManager] request_ProjectDetail_WithObj:forkedPro andBlock:^(id data, NSError *error) {
                [hud hide:YES];
                if (data) {
                    block(data, nil);
                }else{
                    block(nil, error);
                }
            }];
        }else{
            [hud hide:YES];
            block(nil, error);
        }
    }];
}
- (void)request_ReadMeOFProject:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    [[Coding_NetAPIManager sharedManager] request_CodeBranchOrTagWithPath:@"list_branches" withPro:project andBlock:^(id dataTemp, NSError *errorTemp) {
        if (dataTemp) {
            NSArray *branchList = (NSArray *)dataTemp;
            if (branchList.count > 0) {
                __block NSString *defultBranch = @"master";
                [branchList enumerateObjectsUsingBlock:^(CodeBranchOrTag *obj, NSUInteger idx, BOOL *stop) {
                    if (obj.is_default_branch.boolValue) {
                        defultBranch = obj.name;
                    }
                }];
                
                NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/git/tree/%@",project.owner_user_name, project.name, defultBranch];
                [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
                    if (data) {
                        [MobClick event:kUmeng_Event_Request_Get label:@"项目_README"];

                        id resultData = data[@"data"][@"readme"];
                        if (resultData) {
                            CodeFile *rCodeFile = [NSObject objectOfClass:@"CodeFile" fromJSON:data[@"data"]];
                            CodeFile_RealFile *realFile = [NSObject objectOfClass:@"CodeFile_RealFile" fromJSON:resultData];
                            rCodeFile.path = realFile.path;
                            rCodeFile.file = realFile;
                            block(rCodeFile, nil);
                        }else{
                            block(@"我们推荐每个项目都新建一个README文件（客户端暂时不支持创建和编辑README）", nil);
                        }
                    }else{
                        block(nil, error);
                    }
                }];
            }else{
                [MobClick event:kUmeng_Event_Request_Get label:@"项目_README"];

                block(@"我们推荐每个项目都新建一个README文件（客户端暂时不支持创建和编辑README）", nil);
            }
        }else{
            block(@"加载失败...", errorTemp);
        }
    }];
}

- (void)request_FileDiffDetailWithPath:(NSString *)path andBlock:(void (^)(id data, NSError *error))block{
    NSString *commentsPath = [path stringByReplacingOccurrencesOfString:@"/commitDiffContent" withString:@"/commitDiffComment"];
    NSMutableDictionary *resultA = [NSMutableDictionary new];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            resultA[@"rawData"] = data;
            [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:commentsPath withParams:nil withMethodType:Get andBlock:^(id dataC, NSError *errorC) {
                if (dataC) {
                    [MobClick event:kUmeng_Event_Request_Get label:@"文件改动_详情"];
                    
                    resultA[@"commentsData"] = dataC;
                    block(resultA, nil);
                }else{
                    block(nil, error);
                }
            }];
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_ForkTreeWithOwner:(NSString *)owner_name project:(NSString *)project_name andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/user/%@/project/%@/git/forks", owner_name, project_name];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            data = data[@"data"];
            NSArray *resultA = [NSObject arrayFromJSON:data ofObjects:@"Project"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}
#pragma mark Image
- (void)uploadTweetImage:(UIImage *)image
               doneBlock:(void (^)(NSString *imagePath, NSError *error))done
           progerssBlock:(void (^)(CGFloat progressValue))progress{
    if (!image) {
        done(nil, [NSError errorWithDomain:@"DATA EMPTY" code:0 userInfo:@{NSLocalizedDescriptionKey : @"有张照片没有读取成功"}]);
        return;
    }
    [[CodingNetAPIClient sharedJsonClient] uploadImage:image path:@"https://up.qbox.me/" name:@"file" successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSString *reslutString = [responseObject objectForKey:@"data"];
        DebugLog(@"%@", reslutString);
        done(reslutString, nil);
    } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
        done(nil, error);
    } progerssBlock:^(CGFloat progressValue) {
        progress(progressValue);
    }];
}
- (void)request_UpdateUserIconImage:(UIImage *)image
                       successBlock:(void (^)(id responseObj))success
                       failureBlock:(void (^)(NSError *error))failure
                      progerssBlock:(void (^)(CGFloat progressValue))progress{
    if (!image) {
        [NSObject showHudTipStr:@"读图失败"];
        return;
    }
    [NSObject showStatusBarQueryStr:@"正在上传头像"];
    CGSize maxSize = CGSizeMake(800, 800);
    if (image.size.width > maxSize.width || image.size.height > maxSize.height) {
        image = [image scaleToSize:maxSize usingMode:NYXResizeModeAspectFit];
    }
    [[CodingNetAPIClient sharedJsonClient] uploadImage:image path:@"api/user/avatar?update=1" name:@"file" successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
        [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"个人信息_更换头像"];

        [NSObject showStatusBarSuccessStr:@"上传头像成功"];
        id resultData = [responseObject valueForKeyPath:@"data"];
        success(resultData);
    } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
        failure(error);
        [NSObject showStatusBarError:error];
    } progerssBlock:progress];
}

- (void)loadImageWithPath:(NSString *)imageUrlStr completeBlock:(void (^)(UIImage *image, NSError *error))block{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:imageUrlStr]];
    AFHTTPRequestOperation *requestOperation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    requestOperation.responseSerializer = [AFImageResponseSerializer serializer];
    [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        [MobClick event:kUmeng_Event_Request_Get label:@"下载验证码"];

        DebugLog(@"Response: %@", responseObject);
        block(responseObject, nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DebugLog(@"Image error: %@", error);
        block(nil, error);
    }];
    [requestOperation start];
}
#pragma mark Other
- (void)request_Users_WithSearchString:(NSString *)searchStr andBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/user/search" withParams:@{@"key" : searchStr} withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"搜索用户"];

            id resultData = [data valueForKeyPath:@"data"];
            NSMutableArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"User"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_Users_WithTopicID:(NSInteger)topicID andBlock:(void (^)(id data, NSError *error))block {
    NSString *path = [NSString stringWithFormat:@"api/tweet_topic/%ld/hot_joined",(long)topicID];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"话题_热门参与者"];

            id resultData = [data valueForKeyPath:@"data"];
            NSMutableArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"User"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_JoinedUsers_WithTopicID:(NSInteger)topicID page:(NSInteger)page andBlock:(void (^)(id data, NSError *error))block {
    NSString *path = [NSString stringWithFormat:@"api/tweet_topic/%ld/joined",(long)topicID];
    NSDictionary *params = @{
                             @"page":@(page),
                             @"pageSize":@(100)
                             };
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"话题_全部参与者"];

            id resultData = data[@"data"][@"list"];
            NSMutableArray *resultA = [NSObject arrayFromJSON:resultData ofObjects:@"User"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_Users_activenessWithGlobalKey:(NSString *)globalKey andBlock:(void (^)(ActivenessModel *data, NSError *error))block {
    NSString *path = [NSString stringWithFormat:@"api/user/activeness/data/%@",globalKey];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"用户活跃图"];
            
            id resultData = [data valueForKeyPath:@"data"];
            ActivenessModel *resultA = [NSObject objectOfClass:@"ActivenessModel" fromJSON:resultData];
            resultA.dailyActiveness = [NSObject arrayFromJSON:resultData[@"daily_activeness"] ofObjects:@"DailyActiveness"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_MDHtmlStr_WithMDStr:(NSString *)mdStr inProject:(Project *)project andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = @"api/markdown/previewNoAt";
    if (project.name && project.owner_user_name) {
        path = [NSString stringWithFormat:@"api/user/%@/project/%@/markdownNoAt", project.owner_user_name, project.name];
    }
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:@{@"content" : mdStr} withMethodType:Post andBlock:^(id data, NSError *error) {
        [MobClick event:kUmeng_Event_Request_Get label:@"md-html转化"];

        if (data) {
            id resultData = [data valueForKeyPath:@"data"];
            block(resultData, nil);
        }else{
            block([self localMDHtmlStr_WithMDStr:mdStr], error);
        }
    }];
}

- (NSString *)localMDHtmlStr_WithMDStr:(NSString *)mdStr{
    NSError  *error = nil;
    NSString *htmlStr;
    @try {
        htmlStr = [MMMarkdown HTMLStringWithMarkdown:mdStr error:&error];
    }
    @catch (NSException *exception) {
        htmlStr = @"加载失败！";
    }
    if (error) {
        htmlStr = @"加载失败！";
    }
    return htmlStr;
}

- (void)request_VerifyTypeWithBlock:(void (^)(VerifyType type, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/user/2fa/method" withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"高危操作_获取校验类型"];

            VerifyType type = VerifyTypeUnknow;
            NSString *typeStr = [data valueForKey:@"data"];
            if ([typeStr isEqualToString:@"password"]) {
                type = VerifyTypePassword;
            }else if ([typeStr isEqualToString:@"totp"]){
                type = VerifyTypeTotp;
            }
            block(type, nil);
        }else{
            block(VerifyTypeUnknow, error);
        }
    }];
}

#pragma mark - 2FA
- (void)post_Close2FAGeneratePhoneCode:(NSString *)phone withCaptcha:(NSString *)captcha block:(void (^)(id data, NSError *error))block{
    NSMutableDictionary *params = @{@"phone": phone, @"from": @"mart"}.mutableCopy;
    if (captcha.length > 0) {
        params[@"j_captcha"] = captcha;
    }
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/twofa/close/code" withParams:params withMethodType:Post autoShowError:captcha.length > 0 andBlock:^(id data, NSError *error) {
        if (captcha.length <= 0 && error && error.userInfo[@"msg"] && ![[error.userInfo[@"msg"] allKeys] containsObject:@"j_captcha_error"]) {
            [NSObject showError:error];
        }
        block(data, error);
    }];
}

- (void)post_Close2FAWithPhone:(NSString *)phone code:(NSString *)code block:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/twofa/close" withParams:@{@"phone": phone, @"code": code} withMethodType:Post andBlock:^(id data, NSError *error) {
        block(data, error);
    }];
}

- (void)get_is2FAOpenBlock:(void (^)(BOOL data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/user/2fa/method" withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        block([data[@"data"] isEqualToString:@"totp"], error);
    }];
}

#pragma mark -
#pragma mark Topic HotKey

- (void)request_TopicHotkeyWithBlock:(void (^)(id data, NSError *error))block {

    NSString *path = @"/api/tweet_topic/hot?page=1&pageSize=20";
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        
        if(data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"话题_热门话题_Key"];

            id resultData = [data valueForKey:@"data"];
            block(resultData, nil);
        }else {
        
            block(nil, error);
        }
    }];
}

#pragma mark - topic
- (void)request_TopicAdlistWithBlock:(void (^)(id data, NSError *error))block {
    NSString *path = @"/api/tweet_topic/marketing_ad";
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if(data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"话题_Banner"];

            id resultData = [data valueForKey:@"data"];
            block(resultData, nil);
        }else {
            block(nil, error);
        }
    }];
}

- (void)request_HotTopiclistWithBlock:(void (^)(id data, NSError *error))block {
        NSString *path = @"/api/tweet_topic/hot";
        [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
            if(data) {
                [MobClick event:kUmeng_Event_Request_Get label:@"话题_热门话题_榜单"];

                id resultData = [data valueForKey:@"data"];
                block(resultData, nil);
                
            }else {
                block(nil, error);
            }
        }];
}

- (void)request_DefautsHotTopicNamelistWithBlock:(void (^)(id data, NSError *error))block {
    NSString *defaultsPath = @"api/tweet/pop";
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:defaultsPath withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            NSMutableArray *resultList = [[data[@"data"][@"default_topics"] valueForKey:@"name"] mutableCopy];
            NSString *hotPath = @"/api/tweet_topic/hot";
            [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:hotPath withParams:nil withMethodType:Get andBlock:^(id dataHot, NSError *errorHot) {
                if (dataHot) {
                    [MobClick event:kUmeng_Event_Request_Get label:@"话题_热门话题_榜单"];
                    NSMutableArray *hotList = [[dataHot[@"data"] valueForKey:@"name"] mutableCopy];
                    [hotList removeObjectsInArray:resultList];//剔除重复元素
                    [resultList addObjectsFromArray:hotList];//将 hot 追加到 defaults 末尾
                    block(resultList, nil);
                }else{
                    block(nil, errorHot);
                }
            }];
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_Tweet_WithSearchString:(NSString *)strSearch andPage:(NSInteger)page andBlock:(void (^)(id data, NSError *error))block {

    NSString *path = [NSString stringWithFormat:@"/api/search/quick?q=%@&page=%d", strSearch, (int)page];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
       
        if(data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"冒泡_搜索"];

            id resultData = [(NSDictionary *)[data valueForKey:@"data"] objectForKey:@"tweets"];
            block(resultData, nil);
        }else {
        
            block(nil, error);
        }
    }];
}

- (void)requestWithSearchString:(NSString *)strSearch typeStr:(NSString*)type andPage:(NSInteger)page andBlock:(void (^)(id data, NSError *error))block {
    
    NSString *path = [NSString stringWithFormat:@"/api/esearch/%@?q=%@&page=%d",type,strSearch, (int)page];
    if ([type isEqualToString:@"all"]) {
        path=[NSString stringWithFormat:@"%@&types=projects,project_topics,tasks,tweets,files,friends,merge_requests,pull_requests",path];
    }else if ([type isEqualToString:@"public_project"]) {
        path=[NSString stringWithFormat:@"/api/esearch/project?q=%@  related:false&page=%d",strSearch,(int)page];
    }
    
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        
        if(data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"全局_搜索"];
            
//            id resultData = [(NSDictionary *)[data valueForKey:@"data"] objectForKey:@"tweets"];
            id resultData = [data valueForKey:@"data"];
            block(resultData, nil);
        }else {
            
            block(nil, error);
        }
    }];
}


- (void)request_TopicDetailsWithTopicID:(NSInteger)topicID block:(void (^)(id data, NSError *error))block {
    NSString *path = [NSString stringWithFormat:@"/api/tweet_topic/%ld",(long)topicID];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if(data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"话题_详情"];

            id resultData = data[@"data"];
            block(resultData, nil);
        }else {
            
            block(nil, error);
        }
    }];
}

- (void)request_TopTweetWithTopicID:(NSInteger)topicID block:(void (^)(id data, NSError *error))block {
    NSString *path = [NSString stringWithFormat:@"api/public_tweets/topic/%ld/top",(long)topicID];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if(data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"话题_热门冒泡列表"];

            id resultData = data[@"data"];
            Tweet *tweet =[NSObject objectOfClass:@"Tweet" fromJSON:resultData];
            block(tweet, nil);
        }else {
            
            block(nil, error);
        }
    }];
}


- (void)request_JoinedTopicsWithUserGK:(NSString *)userGK page:(NSInteger)page block:(void (^)(id data, BOOL hasMoreData, NSError *error))block {
    NSString *path = [[NSString stringWithFormat:@"api/user/%@/tweet_topic/joined",userGK] stringByAppendingString:[NSString stringWithFormat:@"?page=%d&extraInfo=1", (int)page]];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if(data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"话题_我参与的"];

            id resultData = data[@"data"];
            BOOL hasMoreData = [resultData[@"totalPage"] intValue] - [resultData[@"page"] intValue];
            block(resultData, hasMoreData, nil);
        }else {
            block(nil, NO, error);
        }
    }];
}

- (void)request_WatchedTopicsWithUserGK:(NSString *)userGK page:(NSInteger)page block:(void (^)(id data, BOOL hasMoreData, NSError *error))block {
    NSString *path = [[NSString stringWithFormat:@"/api/user/%@/tweet_topic/watched",userGK] stringByAppendingString:[NSString stringWithFormat:@"?page=%d&extraInfo=1", (int)page]];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if(data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"话题_我关注的"];

            id resultData = data[@"data"];
            BOOL hasMoreData = [resultData[@"totalPage"] intValue] - [resultData[@"page"] intValue];
            block(resultData, hasMoreData, nil);
        }else {
            block(nil, NO, error);
        }
    }];
}

- (void)request_Topic_DoWatch_WithUrl:(NSString *)url andBlock:(void (^)(id data, NSError *error))block{
    
    BOOL isUnwatched = [url hasSuffix:@"unwatch"];
    NetworkMethod method = isUnwatched ? Delete : Post;
    
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:url withParams:nil withMethodType:method andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_ActionOfServer label:@"话题_关注"];

            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_BannersWithBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/banner/type/app" withParams:nil withMethodType:Get autoShowError:NO andBlock:^(id data, NSError *error) {
        if (data) {
            [MobClick event:kUmeng_Event_Request_Get label:@"冒泡列表_Banner"];

            data = [data valueForKey:@"data"];
            NSArray *resultA = [NSArray arrayFromJSON:data ofObjects:@"CodingBanner"];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

#pragma mark-
#pragma mark---------------------- shop ---------------------------


- (void)request_shop_bannersWithBlock:(void (^)(id data, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"/api/gifts/sliders" withParams:nil withMethodType:Get autoShowError:NO andBlock:^(id data, NSError *error) {
        if (data) {
            data = [data valueForKey:@"data"];
            NSArray *resultA = [NSArray arrayFromJSON:data ofObjects:@"ShopBanner"];
            
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_shop_userPointWithShop:(Shop *)_shop andBlock:(void (^)(id data, NSError *error))block
{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/account/points" withParams:nil withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
             data = [data valueForKey:@"data"];
            _shop.points_left = [data objectForKey:@"points_left"];
            _shop.points_total = [data objectForKey:@"points_total"];
            block(data, nil);
        }else
            block(nil, error);
    }];
}


- (void)request_shop_giftsWithShop:(Shop *)_shop andBlock:(void (^)(id data, NSError *error))block
{
    NSDictionary *parsms = @{@"page":_shop.page , @"pageSize":_shop.pageSize};
    _shop.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[_shop toGiftsPath] withParams:parsms withMethodType:Get autoShowError:NO andBlock:^(id data, NSError *error) {
        _shop.isLoading = NO;
        if (data) {
            data = [[data valueForKey:@"data"] valueForKey:@"list"];
            NSArray *resultA = [NSArray arrayFromJSON:data ofObjects:@"ShopGoods"];
            [_shop configWithGiftGoods:resultA];
            
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_shop_OrderListWithOrder:(ShopOrderModel *)_order andBlock:(void (^)(id data, NSError *error))block
{
    NSDictionary *parsms = @{@"page":_order.page , @"pageSize":_order.pageSize};
    _order.isLoading = YES;
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:[_order toPath] withParams:parsms withMethodType:Get autoShowError:NO andBlock:^(id data, NSError *error) {
        _order.isLoading = NO;
        data = [data valueForKey:@"data"];
        if (data) {
            data = [data valueForKey:@"list"];
            NSArray *resultA = [NSArray arrayFromJSON:data ofObjects:@"ShopOrder"];
            [_order configOrderWithReson:resultA];
            block(resultA, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_shop_check_passwordWithpwd:(NSString *)pwd andBlock:(void (^)(id data, NSError *error))block
{
    if ([pwd isEmpty]) {
        return;
    }
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/account/check_password" withParams:@{@"password":[pwd sha1Str]} withMethodType:Post andBlock:^(id data, NSError *error) {
        NSNumber *code = [data valueForKey:@"code"];
        if (!error && code.intValue == 0) {
            block(code, nil);
        }else{
            block(nil, error);
        }
    }];
}
///

- (void)request_shop_exchangeWithParms:(NSDictionary *)parms andBlock:(void (^)(id data, NSError *error))block
{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/gifts/exchange" withParams:parms withMethodType:Post andBlock:^(id data, NSError *error) {
        data = [data valueForKey:@"data"];
        if (data) {
            block(data, nil);
        }else{
            block(nil, error);
        }
    }];
}

- (void)request_shop_orderWithParms:(NSDictionary *)parms andBlock:(void (^)(ShopOrder *shopOrder, NSError *error))block{
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/gifts/orders" withParams:parms withMethodType:Post andBlock:^(id data, NSError *error) {
        block([NSObject objectOfClass:@"ShopOrder" fromJSON:data[@"data"]], error);
    }];
}

- (void)request_shop_payOrder:(NSString *)orderId method:(NSString *)method andBlock:(void (^)(NSDictionary *payDict, NSError *error))block{
    NSDictionary *parms = @{@"pay_method": method};
    NSString *path = [NSString stringWithFormat:@"api/gifts/pay/%@", orderId];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:parms withMethodType:Post andBlock:^(id data, NSError *error) {
        block(data[@"data"], error);
    }];
}


- (void)request_shop_deleteOrder:(NSString *)orderId andBlock:(void (^)(id data, NSError *error))block{
    NSString *path = [NSString stringWithFormat:@"api/gifts/orders/%@", orderId];
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:nil withMethodType:Delete andBlock:^(id data, NSError *error) {
        block(data, error);
    }];
}

- (void)request_LocationListWithParams:(NSDictionary *)params block:(void (^)(id data, NSError *error))block{
    NSString *path  = @"api/region";
    [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:path withParams:params withMethodType:Get andBlock:^(id data, NSError *error) {
        if (data) {
            data = data[@"data"];
        }
        block(data, error);
    }];
}
@end
