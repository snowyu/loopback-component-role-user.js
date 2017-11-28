# Performance

To improve the performance, I've added the `_perms` and `_roleRefs`


还需要一张表缓存引用关系: RoleRef, 可以放在roles表中一起。
发现将用户作为princials放入RoleModel的好处是不用单独注入其他model.

refs没法起到减轻负荷，最多是起到只迭代refs表中的role,但是这些role的权限必须彻底遍历才能获取。
---deprecated:这样简化：约定各个role之间不能有交叉权限这就不需要彻底遍历了。只需要update perms.---
通过修改 _perms from array to object, and count the permissions to allow across the roles.
mongodb 的key不能包含'.'。
决定还是作为数组，元素为: 'Account.find=1'
由于改变时，全部重新计算perms，所以暂时无所谓，切回["Account.find"]


* roleId: PK
* dirty: boolean
* refs: the roleId list which refer this.

另外思路就是作为后台 task，定时更新cache。



## TODO

### 2017-11-27

+ add the `cached` option:
  * `0` 'none': no cache. 每次都需要递归查找权限。
  * `1` 'updated': the perms updated when the role updated
    * Role Model上也有 _perms 缓存
    * `deleteUsedRole` 仅当在该参数下才有用。
  * `2` 'logined': the perms updated when logined or perms is empty.

------------------------

The perfect way is use the stored proc of database(triggers) to sync cache:
But howto MongoDB?

```sql
CREATE TRIGGER cache_perms_insert
  BEFORE INSERT ON `[ModelName]` FOR EACH ROW
BEGIN
  NEW.perms = get_role_perms(NEW.roles)
END

CREATE TRIGGER cache_perms_update
  BEFORE UPDATE ON `[ModelName]` FOR EACH ROW
BEGIN
  IF NEW.roles and NEW.roles <> OLD.roles
    NEW.perms = get_role_perms(NEW.roles)
END
```

